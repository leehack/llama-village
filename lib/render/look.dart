import 'dart:math' as math;

import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import 'quality.dart';

vm.Vector3 _c(double r, double g, double b) => vm.Vector3(r, g, b);

typedef _Rgb = (double, double, double);

/// One sky keyframe: sky gradient, key light, image-based light, exposure,
/// fog and grading.
class _Key {
  const _Key(
    this.hour, {
    required this.zenith,
    required this.horizon,
    required this.ground,
    required this.light,
    required this.intensity,
    required this.env,
    required this.exposure,
    required this.fog,
    required this.fogDensity,
    this.temperature = 0.03,
    this.saturation = 1.3,
    this.inScatter = 0.3,
  });
  final double hour;
  final _Rgb zenith, horizon, ground, light, fog;
  final double intensity, env, exposure, fogDensity, temperature, saturation, inScatter;

  _Key at(double h) => _Key(
    h,
    zenith: zenith,
    horizon: horizon,
    ground: ground,
    light: light,
    intensity: intensity,
    env: env,
    exposure: exposure,
    fog: fog,
    fogDensity: fogDensity,
    temperature: temperature,
    saturation: saturation,
    inScatter: inScatter,
  );
}

const _Key _night = _Key(
  0,
  zenith: (0.008, 0.016, 0.055),
  horizon: (0.035, 0.055, 0.13),
  ground: (0.02, 0.03, 0.045),
  light: (0.55, 0.66, 1.0),
  intensity: 0.42,
  env: 0.24,
  exposure: 1.3,
  fog: (0.025, 0.035, 0.075),
  fogDensity: 0.006,
  temperature: -0.08,
  saturation: 1.15,
  inScatter: 0,
);

const _Key _midday = _Key(
  9,
  zenith: (0.26, 0.5, 0.95),
  horizon: (0.78, 0.86, 0.95),
  ground: (0.42, 0.5, 0.3),
  light: (1.0, 0.94, 0.84),
  intensity: 4.2,
  env: 0.72,
  exposure: 1.0,
  fog: (0.66, 0.77, 0.92),
  fogDensity: 0.0022,
);

final List<_Key> _keys = [
  _night,
  _night.at(4.7),
  // Blue hour before dawn.
  const _Key(
    5.5,
    zenith: (0.04, 0.07, 0.2),
    horizon: (0.28, 0.27, 0.42),
    ground: (0.06, 0.06, 0.08),
    light: (0.6, 0.62, 0.95),
    intensity: 0.4,
    env: 0.34,
    exposure: 1.3,
    fog: (0.22, 0.22, 0.34),
    fogDensity: 0.007,
    temperature: -0.06,
  ),
  // Sunrise, with a warm morning haze.
  const _Key(
    6.3,
    zenith: (0.2, 0.32, 0.64),
    horizon: (1.0, 0.58, 0.4),
    ground: (0.3, 0.3, 0.22),
    light: (1.0, 0.62, 0.38),
    intensity: 1.7,
    env: 0.5,
    exposure: 1.08,
    fog: (0.86, 0.62, 0.48),
    fogDensity: 0.004,
    temperature: 0.12,
    inScatter: 0.6,
  ),
  const _Key(
    7.6,
    zenith: (0.26, 0.46, 0.88),
    horizon: (0.95, 0.84, 0.72),
    ground: (0.4, 0.46, 0.3),
    light: (1.0, 0.86, 0.68),
    intensity: 3.3,
    env: 0.64,
    exposure: 1.0,
    fog: (0.82, 0.8, 0.8),
    fogDensity: 0.0035,
    temperature: 0.06,
    inScatter: 0.4,
  ),
  _midday,
  _midday.at(16.2),
  const _Key(
    17.8,
    zenith: (0.28, 0.46, 0.86),
    horizon: (0.98, 0.82, 0.62),
    ground: (0.42, 0.44, 0.28),
    light: (1.0, 0.84, 0.62),
    intensity: 3.6,
    env: 0.66,
    exposure: 1.0,
    fog: (0.86, 0.78, 0.68),
    fogDensity: 0.0026,
    temperature: 0.08,
    inScatter: 0.4,
  ),
  // Golden hour.
  const _Key(
    19.0,
    zenith: (0.3, 0.4, 0.74),
    horizon: (1.0, 0.64, 0.36),
    ground: (0.4, 0.36, 0.24),
    light: (1.0, 0.66, 0.34),
    intensity: 3.1,
    env: 0.58,
    exposure: 1.02,
    fog: (0.96, 0.66, 0.42),
    fogDensity: 0.004,
    temperature: 0.2,
    saturation: 1.38,
    inScatter: 0.8,
  ),
  const _Key(
    19.9,
    zenith: (0.18, 0.2, 0.46),
    horizon: (1.0, 0.42, 0.24),
    ground: (0.28, 0.22, 0.18),
    light: (1.0, 0.46, 0.24),
    intensity: 1.4,
    env: 0.46,
    exposure: 1.1,
    fog: (0.72, 0.38, 0.3),
    fogDensity: 0.005,
    temperature: 0.16,
    saturation: 1.35,
    inScatter: 0.7,
  ),
  // Blue hour after sunset: the lamps come on.
  const _Key(
    20.6,
    zenith: (0.04, 0.07, 0.24),
    horizon: (0.2, 0.22, 0.46),
    ground: (0.05, 0.05, 0.08),
    light: (0.48, 0.56, 1.0),
    intensity: 0.42,
    env: 0.36,
    exposure: 1.3,
    fog: (0.1, 0.12, 0.26),
    fogDensity: 0.0055,
    temperature: -0.1,
    saturation: 1.25,
    inScatter: 0,
  ),
  _night.at(21.6),
  _night.at(24),
];

vm.Vector3 _mix3(_Rgb a, _Rgb b, double t) => _c(a.$1 + (b.$1 - a.$1) * t, a.$2 + (b.$2 - a.$2) * t, a.$3 + (b.$3 - a.$3) * t);

double _bump(double x, double centre, double half) {
  final d = ((x - centre) / half).abs();
  return d >= 1 ? 0 : 1 - d * d * (3 - 2 * d);
}

/// The film look plus a sky that follows the game clock: a gradient sky for
/// image-based light, a sun by day and a cool moon by night (one shadowed
/// light, so lighting never pops), per-hour fog and grading, AgX, bloom
/// for lamps and windows, ambient occlusion and MSAA. A storm greys the sky,
/// thickens the fog and wets the ground; [quality] switches the costly
/// passes.
class FilmSky {
  FilmSky(this.scene);
  final Scene scene;

  late final GradientSkySource sky = GradientSkySource(sunSharpness: 600);
  late final SkyEnvironment skyEnvironment = SkyEnvironment(
    sky,
    refresh: SkyEnvironmentRefresh.interval,
    interval: const Duration(milliseconds: 1500),
    faceResolution: 64,
    equirectWidth: 256,
  );
  late final SunLight sun = SunLight(
    sky,
    color: _c(1.0, 0.92, 0.8),
    intensity: 4.0,
    castsShadow: true,
    shadowSoftness: 0.05,
    angularRadius: 0.02,
    shadowMapResolution: 2048,
    shadowCascadeCount: 2,
    shadowMaxDistance: 110,
    shadowAmbientStrength: 0.5,
    contactShadows: true,
    contactShadowDistance: 0.25,
  );
  late final DirectionalLight fill = DirectionalLight(color: _c(0.6, 0.75, 1.0), intensity: 0.7);
  late final DirectionalLight rim = DirectionalLight(color: _c(1.0, 0.88, 0.7), intensity: 1.0);

  /// 0 by day, 1 in the dead of night, for lamps, windows and fireflies.
  double darkness = 0;

  /// How stormy it is, easing between 0 and 1.
  double get storm => _storm;
  double _storm = 0;

  /// How wet the ground is: rises fast in a storm and dries over a while.
  double wetness = 0;

  GraphicsQuality _quality = GraphicsQuality.high;
  double? _lastHour;
  double _flash = 0;
  double _nextFlash = 4;
  final math.Random _rng = math.Random(9);

  GraphicsQuality get quality => _quality;
  set quality(GraphicsQuality q) {
    _quality = q;
    scene.ambientOcclusion.enabled = q.ambientOcclusion;
    scene.postProcess.bloom.enabled = q.bloom;
    sun
      ..contactShadows = q.contactShadows
      ..shadowSoftness = q.softShadows ? 0.08 : 0.05
      ..shadowMapResolution = q.shadowMapResolution
      ..shadowCascadeCount = q.shadowCascades;
    if (!q.godRays) scene.godRays.enabled = false;
  }

  void apply() {
    scene.antiAliasingMode = AntiAliasingMode.msaa;
    scene.environmentSettings = EnvironmentSettings(
      skybox: Skybox(sky, intensity: 0.6),
      skyEnvironment: skyEnvironment,
      sunLight: sun,
      environmentIntensity: 0.7,
      toneMapping: ToneMappingMode.agx,
      exposure: 1.0,
      colorGradingEnabled: true,
      saturation: 1.3,
      contrast: 1.08,
      temperature: 0.03,
      bloomEnabled: true,
      bloomThreshold: 1.0,
      bloomIntensity: 0.12,
      bloomScatter: 0.72,
      ambientOcclusionEnabled: true,
      ambientOcclusionMethod: AmbientOcclusionMethod.groundTruth,
      ambientOcclusionRadius: 0.7,
      ambientOcclusionIntensity: 0.9,
      ambientOcclusionMultiBounce: 0.6,
      ambientOcclusionHalfResolution: true,
      depthOfFieldEnabled: false,
      vignetteEnabled: true,
      vignetteIntensity: 0.22,
      fogEnabled: true,
      fogMode: FogMode.exponential,
      fogDensity: 0.004,
      fogSkyColorInfluence: 0.4,
      fogMaxOpacity: 0.65,
      fogHeight: 0,
      fogHeightFalloff: 0.06,
      fogSunInScatterExponent: 6,
      godRaysEnabled: false,
      godRaysIntensity: 0.3,
      godRaysDensity: 0.25,
      godRaysAnisotropy: 0.75,
      godRaysStepCount: 8,
      godRaysMaxDistance: 70,
      godRaysJitter: 1,
    );
    scene.add(
      Node(name: 'fill_rim')
        ..addComponent(DirectionalLightComponent.aimed(fill, -(_c(0.6, 0.5, -0.6)..normalize())))
        ..addComponent(DirectionalLightComponent.aimed(rim, -(_c(0.3, 0.45, -0.85)..normalize()))),
    );
    quality = _quality;
    update(8, storm: false, dt: 1);
  }

  /// Sets the sky for [hour] (0-24, fractional); [storm] greys it out.
  void update(double hour, {required bool storm, required double dt}) {
    _storm += ((storm ? 1.0 : 0.0) - _storm) * math.min(1.0, dt * 1.5);
    // Puddles fill in real time but dry over about an hour of game time.
    final gameHours = _lastHour == null ? 0.0 : (hour - _lastHour!) % 24;
    _lastHour = hour;
    wetness = storm ? math.min(1.0, wetness + dt * 0.25) : math.max(0.0, wetness - (gameHours < 1 ? gameHours : 0) / 1.2);
    var i = 0;
    while (i < _keys.length - 2 && _keys[i + 1].hour <= hour) {
      i++;
    }
    final a = _keys[i], b = _keys[i + 1];
    final t = ((hour - a.hour) / (b.hour - a.hour)).clamp(0.0, 1.0);
    final s = t * t * (3 - 2 * t);
    double lerp(double x, double y) => x + (y - x) * s;
    final st = _storm;
    final keyIntensity = lerp(a.intensity, b.intensity);
    final dark = (1 - (keyIntensity - 0.45) / 1.6).clamp(0.0, 1.0);
    vm.Vector3 storming(vm.Vector3 v, vm.Vector3 grey) => v + (grey * (1 - dark * 0.8) - v) * (st * 0.8);

    sky
      ..zenithColor = storming(_mix3(a.zenith, b.zenith, s), _c(0.16, 0.18, 0.22))
      ..horizonColor = storming(_mix3(a.horizon, b.horizon, s), _c(0.34, 0.37, 0.41))
      ..groundColor = _mix3(a.ground, b.ground, s) * (1 - 0.4 * st);

    // The sun crosses from east (05:55) to west (20:40); otherwise the moon.
    final theta = (hour - 5.9) / 14.8 * math.pi;
    final sunUp = theta > 0 && theta < math.pi;
    // The moon rises in the east at 20:40 and sets in the west at 05:54.
    final moon = ((hour - 20.7) % 24) / 9.2 * math.pi;
    final dir = sunUp
        ? (_c(math.cos(theta), math.sin(theta) * 0.9 + 0.08, 0.3)..normalize())
        : (_c(math.cos(moon), math.sin(moon) * 0.75 + 0.2, 0.45)..normalize());
    sky.sunDirection = dir;
    final light = _mix3(a.light, b.light, s);
    var intensity = keyIntensity * (1 - 0.75 * st);
    if (sunUp) intensity *= math.min(1.0, math.max(0.1, math.sin(theta) * 6));
    sky.sunColor = light * (sunUp ? 6.5 * math.min(1.0, intensity / 2.5) * (1 - 0.9 * st) : 0.9);
    sun
      ..color = light
      ..intensity = intensity;

    _updateFlash(dt);
    // The live look fields; Scene.environmentSettings only returns a copy.
    scene
      ..environmentIntensity = lerp(a.env, b.env) * (1 - 0.4 * st) + _flash * 1.8
      ..exposure = lerp(a.exposure, b.exposure) * (1 - 0.12 * st);
    scene.postProcess.colorGrading
      ..saturation = lerp(a.saturation, b.saturation) - 0.5 * st
      ..temperature = lerp(a.temperature, b.temperature) * (1 - st) - 0.05 * st;

    darkness = dark;
    if (_storm > 0.3) darkness = math.max(darkness, 0.45 * _storm);
    fill.intensity = 0.7 * (1 - darkness * 0.6);
    rim.intensity = 1.0 * (1 - darkness * 0.7);
    // Lamps and windows bloom a little more after dark.
    scene.postProcess.bloom.intensity = 0.1 + 0.08 * darkness;

    scene.fog
      ..color = storming(_mix3(a.fog, b.fog, s), _c(0.3, 0.33, 0.37))
      ..density = lerp(a.fogDensity, b.fogDensity) + 0.014 * st
      ..sunInScatter = lerp(a.inScatter, b.inScatter) * (1 - st);

    // God rays are a full-screen march, so only the sunrise gets them.
    final lowSun = sunUp ? _bump(hour, 6.4, 1.0) * (1 - st) : 0.0;
    scene.godRays
      ..enabled = _quality.godRays && lowSun > 0.02
      ..intensity = 0.28 * lowSun
      ..color = light;
  }

  /// Now and then a lightning flash brightens the storm for a moment.
  void _updateFlash(double dt) {
    _flash = math.max(0.0, _flash - dt * 6);
    if (_storm < 0.8) return;
    _nextFlash -= dt;
    if (_nextFlash <= 0) {
      _flash = 1;
      _nextFlash = 5 + _rng.nextDouble() * 9;
    }
  }
}

PhysicallyBasedMaterial pbr({double rough = 0.85, double metal = 0, vm.Vector3? emissive, double emissiveStrength = 1}) {
  final m = PhysicallyBasedMaterial()
    ..roughnessFactor = rough
    ..metallicFactor = metal;
  if (emissive != null) {
    m
      ..emissiveFactor = vm.Vector4(emissive.x, emissive.y, emissive.z, 1)
      ..emissiveStrength = emissiveStrength;
  }
  return m;
}
