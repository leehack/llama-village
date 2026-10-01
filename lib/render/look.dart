import 'dart:math' as math;

import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

vm.Vector3 _c(double r, double g, double b) => vm.Vector3(r, g, b);

/// One sky keyframe.
class _Key {
  const _Key(this.hour, this.zenith, this.horizon, this.ground, this.light, this.intensity, this.env, this.exposure);
  final double hour;
  final (double, double, double) zenith, horizon, ground, light;
  final double intensity, env, exposure;
}

const List<_Key> _keys = [
  _Key(0, (0.015, 0.025, 0.08), (0.06, 0.08, 0.17), (0.03, 0.04, 0.05), (0.5, 0.62, 1.0), 0.28, 0.2, 1.15),
  _Key(4.6, (0.02, 0.03, 0.09), (0.08, 0.09, 0.19), (0.03, 0.04, 0.05), (0.5, 0.62, 1.0), 0.26, 0.2, 1.15),
  _Key(5.6, (0.08, 0.1, 0.25), (0.55, 0.36, 0.42), (0.08, 0.08, 0.08), (1.0, 0.55, 0.4), 0.25, 0.4, 1.2),
  _Key(6.5, (0.24, 0.38, 0.72), (1.0, 0.64, 0.44), (0.3, 0.32, 0.24), (1.0, 0.66, 0.42), 1.8, 0.55, 1.05),
  _Key(8.5, (0.32, 0.55, 0.95), (0.95, 0.88, 0.78), (0.42, 0.5, 0.3), (1.0, 0.92, 0.8), 4.0, 0.7, 1.0),
  _Key(15.5, (0.3, 0.53, 0.95), (0.95, 0.88, 0.78), (0.42, 0.5, 0.3), (1.0, 0.92, 0.8), 4.0, 0.7, 1.0),
  _Key(18.6, (0.3, 0.45, 0.82), (1.0, 0.76, 0.56), (0.4, 0.42, 0.28), (1.0, 0.78, 0.55), 3.2, 0.62, 1.0),
  _Key(19.9, (0.22, 0.26, 0.55), (1.0, 0.48, 0.3), (0.3, 0.25, 0.2), (1.0, 0.5, 0.28), 1.5, 0.5, 1.05),
  _Key(20.8, (0.06, 0.07, 0.2), (0.34, 0.2, 0.32), (0.06, 0.06, 0.07), (0.7, 0.6, 0.9), 0.2, 0.36, 1.25),
  _Key(21.8, (0.015, 0.025, 0.08), (0.06, 0.08, 0.17), (0.03, 0.04, 0.05), (0.5, 0.62, 1.0), 0.28, 0.2, 1.15),
  _Key(24, (0.015, 0.025, 0.08), (0.06, 0.08, 0.17), (0.03, 0.04, 0.05), (0.5, 0.62, 1.0), 0.28, 0.2, 1.15),
];

vm.Vector3 _mix3((double, double, double) a, (double, double, double) b, double t) =>
    _c(a.$1 + (b.$1 - a.$1) * t, a.$2 + (b.$2 - a.$2) * t, a.$3 + (b.$3 - a.$3) * t);

/// The film look from the spikes plus a sky that follows the game clock:
/// a gradient sky for image-based light, a sun by day and a cool moon by
/// night (one shadowed light, so lighting never pops), AgX, bloom for lit
/// windows, ambient occlusion and MSAA.
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

  /// 0 by day, 1 in the dead of night, for lamps and windows.
  double darkness = 0;
  double _storm = 0;

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
      bloomScatter: 0.7,
      ambientOcclusionEnabled: true,
      ambientOcclusionMethod: AmbientOcclusionMethod.groundTruth,
      ambientOcclusionRadius: 0.6,
      ambientOcclusionIntensity: 0.8,
      depthOfFieldEnabled: false,
      vignetteEnabled: true,
      vignetteIntensity: 0.2,
    );
    scene.add(
      Node(name: 'fill_rim')
        ..addComponent(DirectionalLightComponent.aimed(fill, -(_c(0.6, 0.5, -0.6)..normalize())))
        ..addComponent(DirectionalLightComponent.aimed(rim, -(_c(0.3, 0.45, -0.85)..normalize()))),
    );
    update(8, storm: false, dt: 1);
  }

  /// Sets the sky for [hour] (0-24, fractional); [storm] greys it out.
  void update(double hour, {required bool storm, required double dt}) {
    _storm += ((storm ? 1.0 : 0.0) - _storm) * math.min(1.0, dt * 0.8);
    var i = 0;
    while (i < _keys.length - 2 && _keys[i + 1].hour <= hour) {
      i++;
    }
    final a = _keys[i], b = _keys[i + 1];
    final t = ((hour - a.hour) / (b.hour - a.hour)).clamp(0.0, 1.0);
    final s = t * t * (3 - 2 * t);
    double lerp(double x, double y) => x + (y - x) * s;
    final grey = _c(0.32, 0.35, 0.4);
    vm.Vector3 storming(vm.Vector3 v, double k) => v + (grey * k - v) * (_storm * 0.75);

    final zenith = storming(_mix3(a.zenith, b.zenith, s), 0.8);
    final horizon = storming(_mix3(a.horizon, b.horizon, s), 1.25);
    sky
      ..zenithColor = zenith
      ..horizonColor = horizon
      ..groundColor = _mix3(a.ground, b.ground, s);

    // The sun crosses from east (06:00) to west (20:40); otherwise the moon.
    final theta = (hour - 5.9) / 14.8 * math.pi;
    final sunUp = theta > 0 && theta < math.pi;
    final dir = sunUp ? (_c(math.cos(theta), math.sin(theta) * 0.9 + 0.08, 0.42)..normalize()) : (_c(-0.35, 0.8, 0.45)..normalize());
    sky.sunDirection = dir;
    final light = _mix3(a.light, b.light, s);
    var intensity = lerp(a.intensity, b.intensity) * (1 - 0.72 * _storm);
    if (sunUp) intensity *= math.min(1.0, math.sin(theta) * 6);
    sky.sunColor = light * (sunUp ? 6.5 * math.min(1.0, intensity / 2.5) : 0.9);
    sun
      ..color = light
      ..intensity = intensity;
    final env = scene.environmentSettings;
    env
      ..environmentIntensity = lerp(a.env, b.env) * (1 - 0.25 * _storm)
      ..exposure = lerp(a.exposure, b.exposure);
    darkness = (1 - (lerp(a.intensity, b.intensity) - 0.45) / 1.6).clamp(0.0, 1.0);
    if (_storm > 0.3) darkness = math.max(darkness, 0.45 * _storm);
    fill.intensity = 0.7 * (1 - darkness * 0.6);
    rim.intensity = 1.0 * (1 - darkness * 0.7);
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
