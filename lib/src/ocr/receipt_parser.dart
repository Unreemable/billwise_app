class ParsedReceipt {
  final String? storeName;
  final DateTime? purchaseDate;
  final double? totalAmount;
  final bool hasWarrantyKeyword;

  // معلومات للضمان (إن وُجدت)
  final int? warrantyMonths;           // 6/12/24...
  final DateTime? warrantyStartDate;
  final DateTime? warrantyExpiryDate;

  final String? rawText;

  ParsedReceipt({
    this.storeName,
    this.purchaseDate,
    this.totalAmount,
    required this.hasWarrantyKeyword,
    this.warrantyMonths,
    this.warrantyStartDate,
    this.warrantyExpiryDate,
    this.rawText,
  });
}

class ReceiptParser {
  // كلمات مفتاحية — عربي/إنجليزي
  static const _kwWarranty = [
    'warranty', 'warranties', 'guarantee', 'return', 'exchange',
    'ضمان', 'الضمان', 'استبدال', 'إرجاع', 'ارجاع'
  ];

  // أسماء الأشهر إنجليزي
  static const List<String> _enMonths = [
    'january','february','march','april','may','june',
    'july','august','september','october','november','december'
  ];

  // مكافئ عربي مبسّط (اختياري)
  static const Map<String, int> _arMonthToNum = {
    'يناير': 1, 'فبراير': 2, 'مارس': 3, 'أبريل': 4, 'ابريل': 4, 'مايو': 5,
    'يونيو': 6, 'يوليو': 7, 'أغسطس': 8, 'اغسطس': 8, 'سبتمبر': 9,
    'أكتوبر': 10, 'اكتوبر': 10, 'نوفمبر': 11, 'ديسمبر': 12,
  };

  // صيغ مبلغ: نأخذ الرقم الأكبر غالبًا هو الإجمالي
  // مثال: SAR 1,234.56 | 1234.56 | 12,345 | ر.س 123.45
  static final RegExp _amountRegex = RegExp(
    r'(?:SAR|ر\.?\s?س|﷼)?\s*([0-9]{1,3}(?:[.,][0-9]{3})*|[0-9]+)(?:[.,]([0-9]{2}))?',
    caseSensitive: false,
  );

  // --- توابع مساعدة للتواريخ بدون intl ---

  // يحاول dd/MM/yyyy أو d/M/yyyy
  static DateTime? _parseDayMonthYearSlash(String s) {
    final m = RegExp(r'\b(\d{1,2})/(\d{1,2})/(\d{4})\b').firstMatch(s);
    if (m == null) return null;
    final d = int.parse(m.group(1)!);
    final mo = int.parse(m.group(2)!);
    final y = int.parse(m.group(3)!);
    if (mo < 1 || mo > 12 || d < 1 || d > 31) return null;
    return DateTime(y, mo, d);
  }

  // يحاول yyyy-MM-dd
  static DateTime? _parseYearDash(String s) {
    final m = RegExp(r'\b(\d{4})-(\d{1,2})-(\d{1,2})\b').firstMatch(s);
    if (m == null) return null;
    final y = int.parse(m.group(1)!);
    final mo = int.parse(m.group(2)!);
    final d = int.parse(m.group(3)!);
    if (mo < 1 || mo > 12 || d < 1 || d > 31) return null;
    return DateTime(y, mo, d);
  }

  // يحاول dd MMM yyyy (بالإنجليزية) مثل 15 Aug 2025
  static DateTime? _parseDayMonYearWords(String s) {
    final m = RegExp(r'\b(\d{1,2})\s+([A-Za-z]{3,})\s+(\d{4})\b').firstMatch(s);
    if (m == null) return null;
    final d = int.parse(m.group(1)!);
    final monWord = m.group(2)!.toLowerCase();
    final y = int.parse(m.group(3)!);
    int mo = _enMonths.indexOf(monWord) + 1;
    // دعم مختصرات مثل Aug.
    if (mo == 0) {
      for (int i = 0; i < _enMonths.length; i++) {
        if (_enMonths[i].startsWith(monWord.replaceAll('.', ''))) {
          mo = i + 1;
          break;
        }
      }
    }
    if (mo == 0 || d < 1 || d > 31) return null;
    return DateTime(y, mo, d);
  }

  // يحاول يوم + شهر عربي + سنة: 15 أغسطس 2025
  static DateTime? _parseArabicMonth(String s) {
    final m = RegExp(r'\b(\d{1,2})\s+([اأإآءa-zA-Z]+)\s+(\d{4})\b').firstMatch(s);
    if (m == null) return null;
    final d = int.parse(m.group(1)!);
    final word = m.group(2)!.toLowerCase();
    final y = int.parse(m.group(3)!);

    // طابق عربي
    int? mo = _arMonthToNum[word] ??
        _arMonthToNum.entries
            .firstWhere(
              (e) => word.contains(e.key),
          orElse: () => const MapEntry('', 0),
        )
            .value;
    if (mo == 0) return null;
    if (d < 1 || d > 31) return null;
    return DateTime(y, mo!, d);
  }

  static DateTime? _tryParseDate(String s) {
    s = s.trim().replaceAll(RegExp(r'[\u200f\u200e]'), '');
    return _parseDayMonthYearSlash(s) ??
        _parseYearDash(s) ??
        _parseDayMonYearWords(s) ??
        _parseArabicMonth(s) ??
        _parseLooseYMD(s);
  }

  // آخر محاولة فضفاضة: 2025/8/15 أو 2025.08.15
  static DateTime? _parseLooseYMD(String s) {
    final m = RegExp(r'(\d{4})[^\d]?(\d{1,2})[^\d]?(\d{1,2})').firstMatch(s);
    if (m == null) return null;
    final y = int.parse(m.group(1)!);
    final mo = int.parse(m.group(2)!);
    final d = int.parse(m.group(3)!);
    if (mo < 1 || mo > 12 || d < 1 || d > 31) return null;
    return DateTime(y, mo, d);
  }

  static bool _containsWarrantyKeyword(String text) {
    final t = text.toLowerCase();
    return _kwWarranty.any((k) => t.contains(k));
  }

  static int? _extractWarrantyMonths(String text) {
    final t = text.toLowerCase();

    final numM = RegExp(r'(\d+)\s*(month|months|شهر|أشهر)').firstMatch(t);
    if (numM != null) return int.tryParse(numM.group(1)!);

    final numY = RegExp(r'(\d+)\s*(year|years|سنة|سنوات)').firstMatch(t);
    if (numY != null) return (int.tryParse(numY.group(1)!) ?? 0) * 12;

    if (RegExp(r'\bسنة\b').hasMatch(t)) return 12;
    if (RegExp(r'\bسنتين\b').hasMatch(t)) return 24;
    return null;
  }

  static String? _guessStore(List<String> lines) {
    // نأخذ أول سطرين-ثلاثة لا تحتوي أرقام كثيرة كاسم متجر
    for (int i = 0; i < lines.length && i < 5; i++) {
      final l = lines[i].trim();
      if (l.isEmpty) continue;
      final digits = RegExp(r'\d').allMatches(l).length;
      if (digits <= 2 && l.length <= 40) return l;
    }
    return null;
  }

  static DateTime? _firstDate(List<String> lines) {
    for (final l in lines) {
      final d = _tryParseDate(l);
      if (d != null) return d;
    }
    // ابحث داخل السطر على مقاطع قد تكون تاريخ
    for (final l in lines) {
      final words = l.split(RegExp(r'[\s,]+'));
      for (int i = 0; i < words.length; i++) {
        for (int j = i + 1; j <= (i + 3) && j <= words.length; j++) {
          final d = _tryParseDate(words.sublist(i, j).join(' '));
          if (d != null) return d;
        }
      }
    }
    return null;
  }

  static double? _bestAmount(String text) {
    double best = -1;
    for (final m in _amountRegex.allMatches(text)) {
      final whole = m.group(1) ?? '';
      final cents = m.group(2);
      final normalized = (whole.replaceAll(',', '').replaceAll('،', '')) +
          (cents != null ? '.${cents}' : '');
      final v = double.tryParse(normalized);
      if (v != null && v > best) best = v;
    }
    return best > 0 ? best : null;
  }

  static ParsedReceipt parse(String fullText) {
    final lines = fullText
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final store = _guessStore(lines);
    final date = _firstDate(lines);
    final amount = _bestAmount(fullText);
    final hasW = _containsWarrantyKeyword(fullText);
    final months = _extractWarrantyMonths(fullText);

    DateTime? wStart;
    DateTime? wExpiry;
    if (date != null && months != null) {
      wStart = date;
      wExpiry = DateTime(date.year, date.month + months, date.day);
    }

    return ParsedReceipt(
      storeName: store,
      purchaseDate: date,
      totalAmount: amount,
      hasWarrantyKeyword: hasW,
      warrantyMonths: months,
      warrantyStartDate: wStart,
      warrantyExpiryDate: wExpiry,
      rawText: fullText,
    );
  }
}
