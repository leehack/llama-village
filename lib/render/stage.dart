import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import '../ambient/creatures.dart';
import '../ambient/layout.dart';
import '../sim/geo.dart';
import '../sim/dash.dart';
import '../sim/places.dart';
import '../sim/village.dart';
import 'actors.dart';
import 'animals.dart';
import 'dressing.dart';
import 'festival_props.dart';
import 'look.dart';
import 'particles.dart';
import 'quality.dart';
import 'water.dart';
import 'world.dart';

/// An orbit camera around a ground target that can follow an actor.
class CameraRig {
  vm.Vector3 target = vm.Vector3(1, 0, -5);
  double yaw = 0;
  double pitch = 0.74;
  double distance = 64;
  static const double fov = 28 * math.pi / 180;

  /// Called each frame for the point to follow; null for a free camera.
  vm.Vector3 Function()? follow;
  String? followName;

  /// Metres to shift a followed subject up the screen, clear of the
  /// options panel at the bottom.
  double lift = 0;

  /// A scripted camera (cutscenes, the menu's drone orbit) shown instead
  /// of the orbit view while set.
  PerspectiveCamera? override;

  vm.Vector3 _target = vm.Vector3(1, 0, -5);
  double _yaw = 0, _pitch = 0.74, _distance = 64;

  void orbit(double dx, double dy) {
    yaw -= dx * 0.006;
    pitch = (pitch + dy * 0.004).clamp(0.12, 1.45);
  }

  void pan(double dx, double dy) {
    final k = _distance * 0.0016;
    final right = vm.Vector3(-math.cos(_yaw), 0, math.sin(_yaw));
    final forward = vm.Vector3(-math.sin(_yaw), 0, -math.cos(_yaw));
    target += right * (-dx * k) + forward * (dy * k);
    target.x = target.x.clamp(-55.0, 55.0);
    target.z = target.z.clamp(-60.0, 45.0);
    follow = null;
    followName = null;
  }

  void zoom(double factor) => distance = (distance * factor).clamp(9.0, 140.0);

  void overview() {
    follow = null;
    followName = null;
    target = vm.Vector3(1, 0, -5);
    yaw = 0;
    pitch = 0.74;
    distance = 64;
  }

  void update(double dt) {
    final f = follow;
    if (f != null) target = f() + vm.Vector3(math.sin(yaw), 0, math.cos(yaw)) * lift;
    final k = math.min(1.0, dt * 6);
    _target += (target - _target) * k;
    _yaw += (yaw - _yaw) * k;
    _pitch += (pitch - _pitch) * k;
    _distance += (distance - _distance) * k;
  }

  vm.Vector3 get eye => override?.position ?? orbitEye;

  vm.Vector3 get orbitEye =>
      _target + vm.Vector3(math.sin(_yaw) * math.cos(_pitch), math.sin(_pitch), math.cos(_yaw) * math.cos(_pitch)) * _distance;

  /// Where the orbit view looks.
  vm.Vector3 get orbitTarget => _target + vm.Vector3(0, 1.2, 0);

  PerspectiveCamera camera() =>
      override ?? PerspectiveCamera(position: orbitEye, target: orbitTarget, fovRadiansY: fov, fovNear: 0.5, fovFar: 400);
}

/// Owns the flutter_scene graph: the static world, the sky, the actors and
/// the camera, and mirrors a [Village] into them every frame.
class VillageStage {
  final Scene scene = Scene();
  late final FilmSky sky = FilmSky(scene);
  late final VillageWorld world = VillageWorld(scene);
  final Map<String, LlamaActor> llamas = {};
  final DashActor dash = DashActor();
  final CameraRig rig = CameraRig();
  late final VillageDressing dressing = VillageDressing(scene, world);
  late final PondWater water;
  late final Fireflies fireflies = Fireflies(scene);
  late final FallingLeaves leaves = FallingLeaves(scene, world.crowns);

  /// The festival's spotlight and Golden Bell, hidden until the show.
  late final FestivalProps festival = FestivalProps(scene);

  /// The village's cats, chickens, ducks, dog and butterflies.
  late final AmbientLife life;
  late final AnimalActors animals;
  GraphicsQuality _quality = GraphicsQuality.high;
  bool _reducedMotion = false;
  bool _loaded = false;
  late final Node _ring;
  final List<Node> _rain = [];
  double _rainY = 0;
  String? selected;
  double _wall = 0;

  /// Seconds the stage has been running, for idle motion.
  double get wall => _wall;

  /// Cutscene overrides: the hour the sky shows, and huts whose lights are out.
  double? hourOverride;

  /// Tour override for Pip's scarf; otherwise she wears it once it is returned.
  bool? scarfOverride;
  final Set<String> lightsOut = {};

  Future<void> load(List<String> names) async {
    await Scene.initializeStaticResources();
    sky.apply();
    world.build();
    final (px, pz) = placeCoordinates['pond']!;
    water = PondWater(scene, vm.Vector2(px, pz), 7.7)..build(pondSurface - 0.02);
    dressing.build();
    fireflies.build();
    leaves.build();
    festival.build();
    life = AmbientLife(seed: 17, extraBlockers: [for (final (p, r) in world.treeTrunks) Blocker(p, r + 0.25)]);
    animals = AnimalActors(scene, life)..build();
    for (final n in names) {
      final a = await LlamaActor.load(n);
      llamas[n] = a;
      scene.add(a.root);
    }
    await dash.load();
    scene.add(dash.root);
    _ring = Node(mesh: Mesh(selectionRing(), ringMaterial()))
      ..castsShadows = false
      ..visible = false;
    scene.add(_ring);
    final rain = rainCurtain();
    final wet = pbr(rough: 0.3, emissive: vm.Vector3(0.7, 0.8, 1.0), emissiveStrength: 0.6);
    for (var i = 0; i < 2; i++) {
      final n = Node(mesh: Mesh(rain, wet))
        ..castsShadows = false
        ..visible = false;
      _rain.add(n);
      scene.add(n);
    }
    _loaded = true;
    quality = _quality;
  }

  GraphicsQuality get quality => _quality;

  /// Hands every llama back to the sim and puts the festival props away.
  void unstage() {
    for (final a in llamas.values) {
      a.unstage();
    }
    if (_loaded) festival.hide();
  }

  /// Switches the costly passes, foliage density and particle counts.
  set quality(GraphicsQuality q) {
    _quality = q;
    if (!_loaded) return;
    sky.quality = q;
    dressing.quality = q;
    animals.quality = q;
    _applyMotion();
  }

  bool get reducedMotion => _reducedMotion;

  /// Calms the animals and halves the fireflies and falling leaves.
  set reducedMotion(bool value) {
    _reducedMotion = value;
    if (_loaded) _applyMotion();
  }

  void _applyMotion() {
    final particles = _quality.particles * (_reducedMotion ? 0.5 : 1);
    life.calm = _reducedMotion;
    fireflies.share = particles;
    leaves.share = particles;
  }

  /// Rain falls in two stacked curtains that wrap around, so a storm costs
  /// two draw calls.
  void _updateRain(Village v, double dt) {
    final on = v.storm;
    _rainY = (_rainY + dt * 22) % rainHeight;
    for (var i = 0; i < _rain.length; i++) {
      _rain[i].visible = on;
      if (on) {
        _rain[i].localTransform = vm.Matrix4.translation(vm.Vector3(0, rainHeight * (i + 1) - _rainY - 4, -4));
      }
    }
  }

  void update(Village v, double dt) {
    _wall += dt;
    final hour = hourOverride ?? (v.now.minute + v.minuteFrac) / 60;
    sky.update(hour, storm: v.storm, dt: dt);
    _nightLights(v, hour);
    _watch(v);
    for (final l in v.cast) {
      final a = llamas[l.name]!;
      a.update(v, l, dt, _wall, _headAt);
      if (l.name == 'Pip') a.scarfShown = scarfOverride ?? v.scarf.state == 'returned';
    }
    dash.update(v, dt, _wall);
    _updateRain(v, dt);
    _ambient(v, hour, dt);
    final talking = v.dash.visit != null && rig.follow != null;
    rig.lift += ((talking ? rig.distance * 0.16 : 0) - rig.lift) * math.min(1.0, dt * 3);
    final sel = selected == null ? null : llamas[selected];
    _ring.visible = sel != null && sel.visible;
    if (sel != null) {
      _ring.localTransform = vm.Matrix4.translation(sel.position + vm.Vector3(0, 0.03, 0))..rotateY(_wall * 0.6);
    }
    world.scarfInReeds.visible = v.scarf.state == 'unnoticed' || v.scarf.state == 'missing';
    world.wildflowers.visible = v.crush.flowersToday || v.kb.maybe('bramble_flowers') != null && v.now.minute < 12 * 60;
    world.festivalDecor.visible = v.festival.state != 'unannounced';
    rig.update(dt);
  }

  Village? _watched;
  (DashVisit, int)? _reacted;

  vm.Vector3? _headAt(String who) {
    if (who == 'Dash') return dash.position;
    final a = llamas[who];
    return a != null && a.visible ? a.headWorld : null;
  }

  /// Faces react to the village: news makes a llama look surprised, and
  /// Dash's line lands with a delighted or annoyed llama (and a happy or
  /// drooping Dash).
  void _watch(Village v) {
    if (!identical(v, _watched)) {
      _watched?.events.listeners.remove(_onEvent);
      _watched = v;
      v.events.listeners.add(_onEvent);
    }
    final visit = v.dash.visit;
    final level = visit?.reaction;
    if (visit == null || level == null || visit.stage != VisitStage.done) return;
    final key = (visit, visit.round);
    if (_reacted == key) return;
    _reacted = key;
    dash.react(level);
    final a = llamas[visit.target.name];
    if (level >= 3) a?.react('delight');
    if (level <= 1) a?.react('annoyance');
  }

  void _onEvent(Map<String, Object?> e) {
    if (e['type'] == 'learn' && e['how'] != 'own') llamas[e['who']]?.react('surprise');
  }

  void _ambient(Village v, double hour, double dt) {
    world.wetness = sky.wetness;
    water.update(dt, wind: sky.storm);
    dressing.update(_wall, dt, storm: sky.storm, wetness: sky.wetness);
    fireflies.update(_wall, night: v.storm ? 0 : ((sky.darkness - 0.55) / 0.35).clamp(0.0, 1.0));
    leaves.update(_wall, dt, day: 1 - sky.darkness, storm: sky.storm);
    final d = v.dash;
    life.update(
      AmbientView(
        hour: hour,
        storm: v.storm,
        llamas: [
          for (final l in v.cast)
            if (llamas[l.name]!.visible) ((llamas[l.name]!.position.x, llamas[l.name]!.position.z), v.llamaPose(l).$3),
        ],
        dash: d.pos,
        dashHeight: dash.position.y - groundHeight(d.pos.$1, d.pos.$2),
        dashMoving: d.moving,
      ),
      dt,
    );
    animals.update(_wall);
  }

  void _nightLights(Village v, double hour) {
    final dark = sky.darkness;
    for (final w in world.windows) {
      final owner = w.owner;
      var on = dark;
      if (owner != null) {
        final l = v.byName(owner);
        final home = l.place == l.home && l.activity.kind != 'walk' || l.activity.dest == l.home;
        final lateNight = hour >= 23.5 || hour < 5;
        on = home && !lateNight && !lightsOut.contains(owner) ? dark : 0;
      } else if (hour >= 23 || hour < 4.5) {
        on = 0;
      }
      w.set(w.level + (on - w.level) * 0.08);
    }
    final festive = v.festival.state != 'unannounced' ? 1.0 : 0.0;
    for (var i = 0; i < world.lamps.length; i++) {
      final lamp = world.lamps[i];
      final want = i < 2 ? dark * festive : dark;
      lamp.set(lamp.level + (want - lamp.level) * 0.08);
    }
  }

  /// World position above a llama's head, for its bubble.
  vm.Vector3 headOf(String name) {
    if (name == 'Dash') return dash.position + vm.Vector3(0, 0.75, 0);
    final a = llamas[name]!;
    return a.position + vm.Vector3(0, a.headHeight + 0.25, 0);
  }

  ui.Offset? toScreen(vm.Vector3 p, ui.Size size) => rig.camera().worldToScreen(p, size);

  /// The llama under [screen], if any.
  String? pickLlama(ui.Offset screen, ui.Size size) {
    final ray = rig.camera().screenPointToRay(screen, size);
    final dir = ray.direction.normalized();
    String? best;
    var bestT = double.infinity;
    for (final MapEntry(key: name, value: a) in llamas.entries) {
      if (!a.visible) continue;
      final c = a.position + vm.Vector3(0, 1.1, 0);
      final oc = ray.origin - c;
      final b = oc.dot(dir);
      final disc = b * b - (oc.length2 - 1.35 * 1.35);
      if (disc < 0) continue;
      final t = -b - math.sqrt(disc);
      if (t > 0 && t < bestT) {
        bestT = t;
        best = name;
      }
    }
    return best;
  }

  /// Where [screen] hits the ground, if it does.
  P2? pickGround(ui.Offset screen, ui.Size size) {
    final ray = rig.camera().screenPointToRay(screen, size);
    final dir = ray.direction.normalized();
    var p = ray.origin.clone();
    for (var i = 0; i < 1200; i++) {
      final next = p + dir * 0.4;
      if (next.y <= groundHeight(next.x, next.z)) {
        var lo = 0.0, hi = 0.4;
        for (var k = 0; k < 12; k++) {
          final mid = (lo + hi) / 2;
          final q = p + dir * mid;
          if (q.y <= groundHeight(q.x, q.z)) {
            hi = mid;
          } else {
            lo = mid;
          }
        }
        final hit = p + dir * hi;
        return (hit.x, hit.z);
      }
      p = next;
    }
    return null;
  }
}
