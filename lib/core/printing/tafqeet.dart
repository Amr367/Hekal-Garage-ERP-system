/// Converts integer amounts to Arabic words (Tafqeet) for Egyptian Pounds.
abstract final class Tafqeet {
  static const List<String> _ones = [
    '',
    'واحد',
    'اثنان',
    'ثلاثة',
    'أربعة',
    'خمسة',
    'ستة',
    'سبعة',
    'ثمانية',
    'تسعة',
    'عشرة',
    'أحد عشر',
    'اثنا عشر',
    'ثلاثة عشر',
    'أربعة عشر',
    'خمسة عشر',
    'ستة عشر',
    'سبعة عشر',
    'ثمانية عشر',
    'تسعة عشر',
  ];

  static const List<String> _tens = [
    '',
    '',
    'عشرون',
    'ثلاثون',
    'أربعون',
    'خمسون',
    'ستون',
    'سبعون',
    'ثمانون',
    'تسعون',
  ];

  static const List<String> _hundreds = [
    '',
    'مائة',
    'مائتان',
    'ثلاثمائة',
    'أربعمائة',
    'خمسمائة',
    'ستمائة',
    'سبعمائة',
    'ثمانمائة',
    'تسعمائة',
  ];

  /// Converts an amount in piasters into an Arabic words phrase.
  /// Example: 15000 piasters (150 EGP) -> "مائة وخمسون جنيهاً مصرياً"
  /// Example: 125050 piasters (1250.50 EGP) -> "ألف ومائتان وخمسون جنيهاً مصرياً وخمسون قرشاً"
  static String formatPiasters(int piasters) {
    if (piasters == 0) return 'صفر جنيه مصري';
    final pounds = piasters ~/ 100;
    final remainingPiasters = piasters % 100;

    final parts = <String>[];
    if (pounds > 0) {
      final poundsText = _convertNumber(pounds);
      if (pounds == 1) {
        parts.add('جنيه مصري واحد');
      } else if (pounds == 2) {
        parts.add('جنيهان مصريان');
      } else if (pounds >= 3 && pounds <= 10) {
        parts.add('$poundsText جنيهات مصرية');
      } else {
        parts.add('$poundsText جنيهاً مصرياً');
      }
    }

    if (remainingPiasters > 0) {
      final piastersText = _convertNumber(remainingPiasters);
      if (remainingPiasters == 1) {
        parts.add('قرش واحد');
      } else if (remainingPiasters == 2) {
        parts.add('قرشان');
      } else if (remainingPiasters >= 3 && remainingPiasters <= 10) {
        parts.add('$piastersText قروش');
      } else {
        parts.add('$piastersText قرشاً');
      }
    }

    return parts.isEmpty ? 'صفر جنيه مصري' : parts.join(' و');
  }

  static String _convertNumber(int number) {
    if (number == 0) return '';
    if (number < 20) return _ones[number];
    if (number < 100) {
      final unit = number % 10;
      final ten = number ~/ 10;
      if (unit == 0) return _tens[ten];
      return '${_ones[unit]} و${_tens[ten]}';
    }
    if (number < 1000) {
      final hundred = number ~/ 100;
      final remainder = number % 100;
      if (remainder == 0) return _hundreds[hundred];
      return '${_hundreds[hundred]} و${_convertNumber(remainder)}';
    }
    if (number < 1000000) {
      final thousands = number ~/ 1000;
      final remainder = number % 1000;
      String thousandsText;
      if (thousands == 1) {
        thousandsText = 'ألف';
      } else if (thousands == 2) {
        thousandsText = 'ألفان';
      } else if (thousands >= 3 && thousands <= 10) {
        thousandsText = '${_convertNumber(thousands)} آلاف';
      } else {
        thousandsText = '${_convertNumber(thousands)} ألفاً';
      }

      if (remainder == 0) return thousandsText;
      return '$thousandsText و${_convertNumber(remainder)}';
    }
    if (number < 1000000000) {
      final millions = number ~/ 1000000;
      final remainder = number % 1000000;
      String millionsText;
      if (millions == 1) {
        millionsText = 'مليون';
      } else if (millions == 2) {
        millionsText = 'مليونان';
      } else if (millions >= 3 && millions <= 10) {
        millionsText = '${_convertNumber(millions)} ملايين';
      } else {
        millionsText = '${_convertNumber(millions)} مليوناً';
      }

      if (remainder == 0) return millionsText;
      return '$millionsText و${_convertNumber(remainder)}';
    }
    return number.toString();
  }
}
