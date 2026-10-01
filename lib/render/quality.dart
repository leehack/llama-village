/// How much of the scene's look and life to render; the Settings panel's
/// "Graphics quality".
enum GraphicsQuality {
  low('Low'),
  medium('Medium'),
  high('High');

  const GraphicsQuality(this.label);
  final String label;

  static GraphicsQuality parse(String? name) => values.firstWhere((q) => q.name == name, orElse: () => high);

  bool get ambientOcclusion => this != low;
  bool get bloom => this != low;
  bool get contactShadows => this == high;
  bool get softShadows => this == high;
  bool get godRays => this == high;
  bool get animalShadows => this != low;
  int get shadowMapResolution => this == low ? 1024 : 2048;
  int get shadowCascades => this == low ? 1 : 2;

  /// Share of the grass tufts and flowers drawn.
  double get foliage => switch (this) {
    low => 0.3,
    medium => 0.65,
    high => 1.0,
  };

  /// Share of the fireflies, butterflies and falling leaves drawn.
  double get particles => switch (this) {
    low => 0.35,
    medium => 0.7,
    high => 1.0,
  };
}
