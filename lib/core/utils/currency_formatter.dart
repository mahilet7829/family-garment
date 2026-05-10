import 'package:intl/intl.dart';

class CurrencyFormatter {
  static final NumberFormat _formatter = NumberFormat.currency(
    symbol: 'Br',
    decimalDigits: 2,
  );

  /// Format a number to currency string.
  /// Example: 1234.5 → "$1,234.50"
  static String format(double amount) {
    return _formatter.format(amount);
  }

  /// Format a number without currency symbol.
  /// Example: 1234.5 → "1,234.50"
  static String formatPlain(double amount) {
    return NumberFormat('#,##0.00').format(amount);
  }
}