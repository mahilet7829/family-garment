/// Core physics of textiles: Converts weight to area using GSM.
/// GSM = Grams per Square Meter.
class GsmCalculator {
  /// Convert fabric weight to usable area.
  /// [weightInGrams]: Total fabric weight (1000g = 1kg)
  /// [gsm]: Grams per square meter of the fabric
  /// Returns area in square meters (m²)
  static double weightToArea({
    required double weightInGrams,
    required double gsm,
  }) {
    if (gsm <= 0) throw ArgumentError('GSM must be greater than 0');
    return weightInGrams / gsm;
  }

  /// Convert area back to weight.
  /// [areaInM2]: Fabric area in square meters
  /// [gsm]: Grams per square meter
  /// Returns weight in grams
  static double areaToWeight({
    required double areaInM2,
    required double gsm,
  }) {
    return areaInM2 * gsm;
  }

  /// Calculate GSM from a fabric swatch.
  /// [swatchWeightInGrams]: Weight of the cut swatch
  /// [swatchWidthCm]: Width of swatch in cm
  /// [swatchHeightCm]: Height of swatch in cm
  /// Returns calculated GSM
  static double calculateFromSwatch({
    required double swatchWeightInGrams,
    required double swatchWidthCm,
    required double swatchHeightCm,
  }) {
    double areaInCm2 = swatchWidthCm * swatchHeightCm;
    double areaInM2 = areaInCm2 / 10000; // 1 m² = 10,000 cm²
    if (areaInM2 <= 0) throw ArgumentError('Swatch area must be greater than 0');
    return swatchWeightInGrams / areaInM2;
  }

  /// Quick calculator for 10x10cm swatch (industry standard).
  /// [weightInGrams]: Weight of the 10x10cm fabric piece
  static double quickFrom10x10(double weightInGrams) {
    return calculateFromSwatch(
      swatchWeightInGrams: weightInGrams,
      swatchWidthCm: 10,
      swatchHeightCm: 10,
    );
  }
}