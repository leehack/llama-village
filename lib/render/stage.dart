import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import '../sim/geo.dart';
import '../sim/village.dart';
import 'actors.dart';
import 'look.dart';
import 'world.dart';

/// An orbit camera around a ground target that can follow an actor.
class CameraRig {
  vm.Vector3 target = vm.Vector3(1, 0, -6);
  double yaw = 0;
  double pitch = 0.66;
  double distance = 78;
  static const double fov = 28 * math.pi / 180;

  /// Called each frame for the point to follow; null for a free camera.
  vm.Vector3 Function()? follow;
  String? followName;

  vm.Vector3 _target = vm.Vector3(1, 0, -6);
  double _yaw = 0, _pitch = 0.66, _distance = 78;

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
    target = vm.Vector3(1, 0, -6);
    yaw = 0;
    pitch = 0.66;
    distance = 78;
  }

  void update(double dt) {
    final f = follow;
    if (f != null) target = f();
    final k = math.min(1.0, dt * 6);
    _target += (target - _target) * k;
    _yaw += (yaw - _yaw) * k;
    _pitch += (pitch - _pitch) * k;
    _distance += (distance - _distance) * k;
  }

  vm.Vector3 get eye =>
      _target + vm.Vector3(math.sin(_yaw) * math.cos(_pitch), math.sin(_pitch), math.cos(_yaw) * math.cos(_pitch)) * _distance;

  PerspectiveCamera camera() =>
      PerspectiveCamera(position: eye, target: _target + vm.Vector3(0, 1.2, 0), fovRadiansY: fov, fovNear: 0.5, fovFar: 400);
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
  late final Node _ring;
  String? selected;
  double _wall = 0;

  Future<void> load(List<String> names) async {
    await Scene.initializeStaticResources();
    sky.apply();
    world.build();
    for (final n in names) {
      final a = await LlamaActor.load(n);
      llamas[n] = a;
      scene.add(a.root);
    }
    dash.build(pbr(rough: 0.35));
    scene.add(dash.root);
    _ring = Node(mesh: Mesh(selectionRing(), ringMaterial()))
      ..castsShadows = false
      ..visible = false;
    scene.add(_ring);
  }

  void update(Village v, double dt) {
    _wall += dt;
    final hour = (v.now.minute + v.minuteFrac) / 60;
    sky.update(hour, storm: v.storm, dt: dt);
    _nightLights(v, hour);
    for (final l in v.cast) {
      final a = llamas[l.name]!;
      a.update(v, l, dt, _wall);
      if (l.name == 'Pip') a.scarfShown = v.scarf.state == 'returned';
    }
    dash.update(v, dt, _wall);
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

  void _nightLights(Village v, double hour) {
    final dark = sky.darkness;
    for (final w in world.windows) {
      final owner = w.owner;
      var on = dark;
      if (owner != null) {
        final l = v.byName(owner);
        final home = l.place == l.home && l.activity.kind != 'walk' || l.activity.dest == l.home;
        final lateNight = hour >= 23.5 || hour < 5;
        on = home && !lateNight ? dark : 0;
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
    return a.position + vm.Vector3(0, LlamaActor.headHeight + 0.25, 0);
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
