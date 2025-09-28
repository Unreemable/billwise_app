class ParsedReceipt {
  final String? storeName;
  final DateTime? purchaseDate;
  final double? totalAmount;
  final bool hasWarrantyKeyword;

  final int? warrantyMonths;
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
  // كلمات ضمان
  static const _kwWarranty = [
    'warranty','warranties','guarantee','return','exchange',
    'ضمان','الضمان','استبدال','إرجاع','ارجاع'
  ];

  // أشهر إنجليزي
  static const List<String> _enMonths = [
    'january','february','march','april','may','june',
    'july','august','september','october','november','december'
  ];

  // أشهر عربي
  static const Map<String, int> _arMonthToNum = {
    'يناير': 1, 'فبراير': 2, 'مارس': 3, 'أبريل': 4, 'ابريل': 4, 'مايو': 5,
    'يونيو': 6, 'يوليو': 7, 'أغسطس': 8, 'اغسطس': 8, 'سبتمبر': 9,
    'أكتوبر': 10, 'اكتوبر': 10, 'نوفمبر': 11, 'ديسمبر': 12,
  };

  // مفاتيح إيجابية/سلبية لاستخراج الإجمالي فقط
  static const _positiveKeys = [
    'total','grand total','amount due','balance due','payable','net total','net amount',
    'الإجمالي','الاجمالي','المجموع','الصافي','الإجمالي مع الضريبة','المبلغ المستحق','المبلغ الإجمالي'
  ];
  static const _negativeKeys = [
    'vat','v.a.t','tax','trn','tin','tax id','vat no','vat number',
    'رقم الضريبة','الرقم الضريبي','قيمة الضريبة','نسبة الضريبة',
    'خصم','discount','subtotal','sub total','delivery','shipping',
    'quantity','qty','unit price'
  ];

  // أرقام عربية -> لاتينية
  static String _normalizeDigits(String s) {
    const ar = '٠١٢٣٤٥٦٧٨٩';
    final buf = StringBuffer();
    for (final ch in s.runes) {
      final c = String.fromCharCode(ch);
      final idx = ar.indexOf(c);
      buf.write(idx == -1 ? c : idx.toString());
    }
    return buf.toString();
  }

  // تنظـيف سطر: أرقام + توحيد رموز العملة + lower-case
  static String _normalizeLine(String line) {
    var L = _normalizeDigits(line)
        .replaceAll('\u200f', '')
        .replaceAll('\u200e', '')
        .replaceAll('SAR', 'sar')
        .replaceAll('ر.س', 'sar')
        .replaceAll('﷼', 'sar')
        .replaceAll('ريال', 'sar')
        .toLowerCase();
    L = L.replaceAll(RegExp(r'\s+'), ' ').trim();
    return L;
  }

  // استخراج أرقام مالية من سطر (يدعم 1,234.56 / 1234,56 / 1234)
  static Iterable<double> _numbersIn(String line) sync* {
    final cleaned = line.replaceAll('sar', '');
    final re = RegExp(r'(?<!\d)(\d{1,3}(?:[,\s]\d{3})*|\d+)(?:[.,]\d{2})?(?!\d)');
    for (final m in re.allMatches(cleaned)) {
      var token = m.group(0)!;

      // تجاهل نسب %
      if (token.contains('%') || cleaned.contains('%')) continue;

      // تحديد الفاصلة العشرية
      final commas = RegExp(',').allMatches(token).length;
      final dots = RegExp(r'\.').allMatches(token).length;
      if (commas > 0 && dots == 0) {
        // نمط أوروبي: 1.234,56 أو 1234,56
        token = token.replaceAll('.', '').replaceAll(',', '.');
      } else {
        // نمط إنجليزي: 1,234.56 أو 1234.56
        token = token.replaceAll(',', '');
      }

      final v = double.tryParse(token);
      if (v != null) {
        if (v <= 0) continue;
        if (v > 1e9) continue; // احتمال رقم طويل مثل رقم ضريبي
        yield v;
      }
    }
  }

  static bool _containsAny(String line, List<String> keys) {
    return keys.any((k) => line.contains(k));
  }

  // ---------- تواريخ ----------
  static DateTime? _parseDayMonthYearSlash(String s) {
    final m = RegExp(r'\b(\d{1,2})/(\d{1,2})/(\d{4})\b').firstMatch(s);
    if (m == null) return null;
    final d = int.parse(m.group(1)!);
    final mo = int.parse(m.group(2)!);
    final y = int.parse(m.group(3)!);
    if (mo < 1 || mo > 12 || d < 1 || d > 31) return null;
    return DateTime(y, mo, d);
  }

  static DateTime? _parseYearDash(String s) {
    final m = RegExp(r'\b(\d{4})-(\d{1,2})-(\d{1,2})\b').firstMatch(s);
    if (m == null) return null;
    final y = int.parse(m.group(1)!);
    final mo = int.parse(m.group(2)!);
    final d = int.parse(m.group(3)!);
    if (mo < 1 || mo > 12 || d < 1 || d > 31) return null;
    return DateTime(y, mo, d);
  }

  static DateTime? _parseDayMonYearWords(String s) {
    final m = RegExp(r'\b(\d{1,2})\s+([A-Za-z]{3,})\s+(\d{4})\b').firstMatch(s);
    if (m == null) return null;
    final d = int.parse(m.group(1)!);
    final monWord = m.group(2)!.toLowerCase().replaceAll('.', '');
    final y = int.parse(m.group(3)!);
    int mo = _enMonths.indexOf(monWord) + 1;
    if (mo == 0) {
      for (int i = 0; i < _enMonths.length; i++) {
        if (_enMonths[i].startsWith(monWord)) { mo = i + 1; break; }
      }
    }
    if (mo == 0 || d < 1 || d > 31) return null;
    return DateTime(y, mo, d);
  }

  static DateTime? _parseArabicMonth(String s) {
    final m = RegExp(r'\b(\d{1,2})\s+([اأإآءa-zA-Z]+)\s+(\d{4})\b').firstMatch(s);
    if (m == null) return null;
    final d = int.parse(m.group(1)!);
    final word = m.group(2)!.toLowerCase();
    final y = int.parse(m.group(3)!);
    int? mo = _arMonthToNum[word] ??
        _arMonthToNum.entries.firstWhere(
              (e) => word.contains(e.key),
          orElse: () => const MapEntry('', 0),
        ).value;
    if (mo == 0) return null;
    if (d < 1 || d > 31) return null;
    return DateTime(y, mo!, d);
  }

  static DateTime? _parseLooseYMD(String s) {
    final m = RegExp(r'(\d{4})[^\d]?(\d{1,2})[^\d]?(\d{1,2})').firstMatch(s);
    if (m == null) return null;
    final y = int.parse(m.group(1)!);
    final mo = int.parse(m.group(2)!);
    final d = int.parse(m.group(3)!);
    if (mo < 1 || mo > 12 || d < 1 || d > 31) return null;
    return DateTime(y, mo, d);
  }

  static DateTime? _tryParseDate(String s) {
    s = _normalizeDigits(s).trim().replaceAll(RegExp(r'[\u200f\u200e]'), '');
    return _parseDayMonthYearSlash(s) ??
        _parseYearDash(s) ??
        _parseDayMonYearWords(s) ??
        _parseArabicMonth(s) ??
        _parseLooseYMD(s);
  }

  // ---------- ضمان ----------
  static bool _containsWarrantyKeyword(String text) {
    final t = text.toLowerCase();
    return _kwWarranty.any((k) => t.contains(k));
  }

  static int? _extractWarrantyMonths(String text) {
    final t = _normalizeDigits(text.toLowerCase());

    final numM = RegExp(r'(\d+)\s*(month|months|شهر|أشهر)').firstMatch(t);
    if (numM != null) return int.tryParse(numM.group(1)!);

    final numY = RegExp(r'(\d+)\s*(year|years|سنة|سنوات)').firstMatch(t);
    if (numY != null) return (int.tryParse(numY.group(1)!) ?? 0) * 12;

    if (RegExp(r'\bسنة\b').hasMatch(t)) return 12;
    if (RegExp(r'\bسنتين\b').hasMatch(t)) return 24;
    return null;
  }

  // ---------- المتجر ----------
  static String? _guessStore(List<String> lines) {
    const blacklist = [
      'vat','v.a.t','tax','trn','tin','tax id','vat no','vat number',
      'رقم','ضريبة','الرقم الضريبي','فاتورة','invoice','bill',
      'date','time','التاريخ','الوقت','subtotal','total','المجموع','الإجمالي',
      'رقم الفاتورة','invoice no','po box','p.o. box'
    ];

    String? best;
    int bestScore = -1;

    for (int i = 0; i < lines.length && i < 8; i++) {
      final raw = lines[i].trim();
      if (raw.isEmpty) continue;

      final l = _normalizeDigits(raw).toLowerCase();

      if (blacklist.any((w) => l.contains(w))) continue;
      if (RegExp(r'\b\d{5,}\b').hasMatch(l)) continue;

      final label = RegExp(
        r'^(store|shop|merchant|seller|branch|المتجر|المحل|البائع|الفرع)\s*[:\-]\s*',
      ).firstMatch(l);
      final candidate = label != null
          ? raw.substring(label.group(0)!.length).trim()
          : raw;

      final digitCount  = RegExp(r'\d').allMatches(candidate).length;
      final letterCount = RegExp(r'[A-Za-z\u0600-\u06FF]').allMatches(candidate).length;

      var score = 0;
      if (i <= 2) score += 3;
      else if (i <= 5) score += 1;
      if (letterCount >= 3) score += 3;
      if (digitCount <= 2) score += 2;
      if (candidate.length <= 30) score += 2;
      if (RegExp(r'^(co|company|llc|ltd|inc|مؤسسة|شركة|مجموعة|محل|سوبر ماركت|صيدلية)',
          caseSensitive: false).hasMatch(candidate)) score += 2;

      if (score > bestScore) {
        best = candidate;
        bestScore = score;
      }
    }
    return best;
  }

  // ---------- التاريخ ----------
  static DateTime? _firstDate(List<String> lines) {
    for (final l in lines) {
      final d = _tryParseDate(l);
      if (d != null) return d;
    }
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

  // ---------- استخراج الإجمالي الذكي ----------
  static double? _extractTotal(String fullText) {
    if (fullText.trim().isEmpty) return null;

    final lines = fullText
        .split(RegExp(r'\r?\n'))
        .map(_normalizeLine)
        .where((l) => l.isNotEmpty)
        .toList();

    const extraPositive = [
      'amount','grand amount','amount payable','amount paid',
      'المبلغ','المبلغ الكلي','المبلغ النهائي','الإجمالي شامل الضريبة'
    ];

    final allPositives = [..._positiveKeys, ...extraPositive];

    final scored = <double, int>{};
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (_containsAny(line, allPositives) && !_containsAny(line, _negativeKeys)) {
        for (final v in _numbersIn(line)) {
          scored[v] = (scored[v] ?? 0) + 10;
        }
        if (i + 1 < lines.length) {
          for (final n in _numbersIn(lines[i + 1])) {
            scored[n] = (scored[n] ?? 0) + 8;
          }
        }
        if (i - 1 >= 0) {
          for (final p in _numbersIn(lines[i - 1])) {
            scored[p] = (scored[p] ?? 0) + 6;
          }
        }
      }
    }

    if (scored.isNotEmpty) {
      final best = scored.entries.toList()
        ..sort((a, b) {
          final byScore = b.value.compareTo(a.value);
          return byScore != 0 ? byScore : b.key.compareTo(a.key);
        });
      return best.first.key;
    }

    final candidates = <double>[];
    for (final line in lines) {
      if (_containsAny(line, _negativeKeys)) continue;
      if (RegExp(r'\b\d{9,15}\b').hasMatch(line)) continue;
      candidates.addAll(_numbersIn(line));
    }
    candidates.removeWhere((v) => v < 5);
    candidates.sort();
    return candidates.isNotEmpty ? candidates.last : null;
  }

  // ---------- نقطة الدخول ----------
  static ParsedReceipt parse(String fullText) {
    final raw = fullText;
    final lines = raw
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final store = _guessStore(lines);
    final date = _firstDate(lines);
    final amount = _extractTotal(raw);
    final hasW = _containsWarrantyKeyword(raw);
    final months = _extractWarrantyMonths(raw);

    DateTime? wStart;
    DateTime? wExpiry;
    if (date != null && months != null) {
      wStart = DateTime(date.year, date.month, date.day);
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
      rawText: raw,
    );
  }
}
