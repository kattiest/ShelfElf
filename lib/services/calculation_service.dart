/// Pure calculation helpers mirroring the C++ CalculationModule.
///
/// All methods are static — no instantiation needed.
class CalculationService {
  CalculationService._();

  /// Total number of servings in a package.
  ///
  /// Returns 0 if [servingSize] is zero or negative to avoid division by zero.
  static double totalServings(double packageSize, double servingSize) {
    if (servingSize <= 0) return 0;
    return packageSize / servingSize;
  }

  /// Percent of the item that remains (inverse of [percentUsed]).
  ///
  /// [percentUsed] must be in the range 0–100.
  static int percentRemaining(int percentUsed) {
    return (100 - percentUsed).clamp(0, 100);
  }

  /// Number of servings remaining, calculated from package size, serving size,
  /// and how much of the package is left.
  ///
  /// [percentUsed] must be in the range 0–100.
  static double servingsRemaining(
    double packageSize,
    double servingSize,
    int percentUsed,
  ) {
    final total = totalServings(packageSize, servingSize);
    final remaining = percentRemaining(percentUsed) / 100.0;
    return total * remaining;
  }

  /// Returns `true` when the item's remaining percent is at or below the
  /// [orderingLevel] threshold.
  static bool isLow(int percentUsed, int orderingLevel) {
    return percentRemaining(percentUsed) <= orderingLevel;
  }
}
