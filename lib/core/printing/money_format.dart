/// Lightweight money formatting for the printing spike.
///
/// The full money utilities (parsing, validation, round-trip tests) live
/// in Phase 2. This file provides only what the PDF builders need now:
/// formatting integer piasters as a human-readable string with thousands
/// separators and exactly two decimal places using Western digits.
abstract final class MoneyFormat {
  /// Formats [piasters] as "1,250.50".
  ///
  /// Always uses Western digits, a comma as thousands separator,
  /// and a dot as the decimal separator.
  static String format(int piasters) {
    final bool negative = piasters < 0;
    final int abs = piasters.abs();
    final int pounds = abs ~/ 100;
    final int piastres = abs % 100;

    // Format pounds with thousands separators.
    final String poundsStr = _withThousandsSeparator(pounds);
    final String piastresStr = piastres.toString().padLeft(2, '0');

    final String formatted = '$poundsStr.$piastresStr';
    return negative ? '-$formatted' : formatted;
  }

  /// Formats [piasters] as "1,250.50 ج.م".
  static String formatWithCurrency(int piasters) {
    return '${format(piasters)} ج.م';
  }

  static String _withThousandsSeparator(int value) {
    final String raw = value.toString();
    final StringBuffer buf = StringBuffer();
    int count = 0;
    for (int i = raw.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) {
        buf.write(',');
      }
      buf.write(raw[i]);
      count++;
    }
    return buf.toString().split('').reversed.join();
  }
}
