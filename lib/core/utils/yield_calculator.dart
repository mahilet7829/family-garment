import 'gsm_calculator.dart';
/// Calculates how many garments can be produced from available materials.
class YieldCalculator {
  /// Calculate maximum pieces from available fabric.
  /// [availableWeightInKg]: How much fabric the user has
  /// [fabricGsm]: The GSM of the fabric
  /// [areaPerPieceInM2]: How much area one garment needs
  /// Returns maximum whole pieces possible
  static int calculateMaxPiecesFromFabric({
    required double availableWeightInKg,
    required double fabricGsm,
    required double areaPerPieceInM2,
  }) {
    double weightInGrams = availableWeightInKg * 1000;
    double totalAreaM2 = GsmCalculator.weightToArea(
      weightInGrams: weightInGrams,
      gsm: fabricGsm,
    );
    return (totalAreaM2 / areaPerPieceInM2).floor();
  }

  /// Calculate fabric needed for a specific number of pieces.
  /// [pieces]: Number of garments to produce
  /// [areaPerPieceInM2]: Area needed per garment
  /// [fabricGsm]: GSM of the fabric
  /// Returns weight in kg needed
  static double calculateFabricNeededInKg({
    required int pieces,
    required double areaPerPieceInM2,
    required double fabricGsm,
  }) {
    double totalAreaM2 = pieces * areaPerPieceInM2;
    double weightInGrams = GsmCalculator.areaToWeight(
      areaInM2: totalAreaM2,
      gsm: fabricGsm,
    );
    return weightInGrams / 1000;
  }

  /// Check if enough non-fabric material exists.
  /// [required]: Amount needed for production
  /// [available]: Current stock
  /// Returns true if sufficient
  static bool isMaterialSufficient({
    required double required,
    required double available,
  }) {
    return available >= required;
  }
}