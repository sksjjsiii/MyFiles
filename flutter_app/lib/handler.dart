import 'dart:async';
import 'dart:convert';
import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart' hide TextDirection;
import 'package:html/parser.dart' as html_parser;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:persian_datetimepickers/persian_datetimepickers.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:persian_number_utility/persian_number_utility.dart';
import 'logic.dart';

// -------------------- Helpers --------------------
String formatRial(double amount) {
  final formatted = NumberFormat('#,###').format(amount);
  return formatted.toPersianDigit();
}

String formatDoubleWithoutTrailingZeros(double value) {
  if (value == value.roundToDouble()) {
    return value.round().toString();
  } else {
    String str = value.toString();
    if (str.contains('.')) {
      str = str.replaceAll(RegExp(r'0*$'), '');
      if (str.endsWith('.')) str = str.substring(0, str.length - 1);
    }
    return str;
  }
}

String formatNumberFa(dynamic value) {
  final double v = value is num
      ? value.toDouble()
      : double.tryParse(value.toString()) ?? 0;
  final formatted = NumberFormat('#,###.###').format(v);
  return formatted.toPersianDigit();
}

String formatWithSeparator(double value) {
  if (value == 0) return '';
  return NumberFormat('#,###').format(value);
}

String formatJalaliDate(DateTime dt) {
  final j = Jalali.fromDateTime(dt);
  return '${j.year}/${j.month.toString().padLeft(2, '0')}/${j.day.toString().padLeft(2, '0')}'
      .toPersianDigit();
}

String formatTime(DateTime dt) {
  return DateFormat('HH:mm').format(dt).toPersianDigit();
}

String coinName(String t) {
  switch (t) {
    case 'coin_new':
      return 'سکه تمام (امامی)';
    case 'coin_old':
      return 'سکه تمام (قدیم)';
    case 'coin_half':
      return 'نیم سکه';
    case 'coin_quarter':
      return 'ربع سکه';
    case 'coin_1g':
      return 'سکه یک گرمی';
    default:
      return t;
  }
}

String goldTypeName(String k) {
  switch (k) {
    case 'gold_18':
      return 'طلای ۱۸ عیار';
    case 'gold_24':
      return 'طلای ۲۴ عیار';
    case 'gold_ons':
      return 'انس طلا';
    case 'gold_mazneh':
      return 'مظنه تهران';
    case 'coin_old':
      return 'سکه قدیم';
    case 'coin_new':
      return 'سکه جدید';
    case 'coin_half':
      return 'نیم سکه';
    case 'coin_quarter':
      return 'ربع سکه';
    case 'coin_1g':
      return 'سکه یک گرمی';
    default:
      return k;
  }
}

String formatToman(double amount) {
  final toman = amount / 10;
  final formatted = NumberFormat('#,###').format(toman);
  return '${formatted.toPersianDigit()} تومان';
}

String numberToTomanWords(double amount) {
  final toman = amount / 10;
  final intValue = toman.round();
  final words = intValue.toString().toWord();
  return '${words.toPersianDigit()} تومان';
}

String convertPersianDigitsToEnglish(String input) {
  const persian = '۰۱۲۳۴۵۶۷۸۹';
  const arabic = '٠١٢٣٤٥٦٧٨٩';
  String result = input;
  for (int i = 0; i < 10; i++) {
    result = result
        .replaceAll(persian[i], i.toString())
        .replaceAll(arabic[i], i.toString());
  }
  return result;
}

// -------------------- Input Formatter --------------------
class PersianAwareNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;
    final converted = convertPersianDigitsToEnglish(newValue.text);
    final clean = converted.replaceAll(RegExp(r'[^\d]'), '');
    if (clean.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }
    final intValue = int.tryParse(clean);
    if (intValue == null) return newValue;
    final formatted = NumberFormat('#,###').format(intValue);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

// -------------------- Number Input Widget --------------------
class NumberInputWithToman extends StatefulWidget {
  final String label;
  final String? initialValue;
  final TextEditingController? controller;
  final ValueChanged<String>? onSaved;
  final TextInputType keyboardType;
  final FormFieldValidator<String>? validator;
  final bool isPrice;

  const NumberInputWithToman({
    Key? key,
    required this.label,
    this.initialValue,
    this.controller,
    this.onSaved,
    this.keyboardType = TextInputType.number,
    this.validator,
    this.isPrice = true,
  }) : super(key: key);

  @override
  _NumberInputWithTomanState createState() => _NumberInputWithTomanState();
}

class _NumberInputWithTomanState extends State<NumberInputWithToman> {
  late TextEditingController _controller;
  bool _ownsController = false;
  String _tomanText = '';
  String _wordsText = '';

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller = widget.controller!;
    } else {
      _controller = TextEditingController(text: widget.initialValue ?? '');
      _ownsController = true;
    }
    _updateDisplay(_controller.text);
    _controller.addListener(_onTextChanged);
  }

  void _onTextChanged() => _updateDisplay(_controller.text);

  void _updateDisplay(String value) {
    final converted = convertPersianDigitsToEnglish(value);
    final clean = converted.replaceAll(RegExp(r'[^\d]'), '');
    if (clean.isNotEmpty && widget.isPrice) {
      final num = double.tryParse(clean) ?? 0;
      setState(() {
        _tomanText = formatToman(num);
        _wordsText = numberToTomanWords(num);
      });
    } else {
      setState(() {
        _tomanText = '';
        _wordsText = '';
      });
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _controller,
          decoration: InputDecoration(
            labelText: widget.label,
            labelStyle: TextStyle(fontFamily: 'Vazir'),
          ),
          keyboardType: widget.keyboardType,
          textAlign: TextAlign.left,
          textDirection: TextDirection.ltr,
          inputFormatters: [
            PersianAwareNumberFormatter(),
          ],
          validator: widget.validator,
          onSaved: widget.onSaved == null
              ? null
              : (v) {
                  final converted = convertPersianDigitsToEnglish(v ?? '');
                  final cleaned = converted.replaceAll(RegExp(r'[^\d]'), '');
                  widget.onSaved!(cleaned);
                },
        ),
        if (_tomanText.isNotEmpty && widget.isPrice)
          Padding(
            padding: const EdgeInsets.only(top: 4.0, right: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _tomanText,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  textDirection: TextDirection.rtl,
                ),
                Text(
                  _wordsText,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  textDirection: TextDirection.rtl,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

Future<DateTime?> pickJalaliDate(BuildContext context, DateTime initial) async {
  final picked = await showPersianDatePicker(
    context: context,
    initialDate: initial,
    firstDate: DateTime(1370, 1, 1),
    lastDate: DateTime.now(),
  );
  return picked;
}

// -------------------- ApiService --------------------
class ApiService {
  static const String _pageUrl = 'https://www.estjt.ir/price/';

  static const Map<String, String> _nameToKey = {
    'انس طلا': 'gold_ons',
    'مظنه تهران': 'gold_mazneh',
    'طلای ۱۸ عیار': 'gold_18',
    'طلای ۲۴ عیار': 'gold_24',
    'سکه طرح قدیم': 'coin_old',
    'سکه طرح جدید': 'coin_new',
    'نیم سکه': 'coin_half',
    'ربع سکه': 'coin_quarter',
    'سکه یک گرمی': 'coin_1g',
  };

  static String _persianToEnglish(String s) {
    const persian = '۰۱۲۳۴۵۶۷۸۹';
    const english = '0123456789';
    final buf = StringBuffer();
    for (final ch in s.runes) {
      final c = String.fromCharCode(ch);
      final i = persian.indexOf(c);
      buf.write(i != -1 ? english[i] : c);
    }
    return buf.toString();
  }

  static double? _parsePrice(String text) {
    if (text.trim() == '—') return null;
    final cleaned = _persianToEnglish(text).replaceAll(RegExp(r'[^\d.]'), '');
    return cleaned.isEmpty ? null : double.tryParse(cleaned);
  }

  static Map<String, double?>? _parseChange(String text) {
    final t = _persianToEnglish(text);
    final m = RegExp(r'([\d.]+)\s*\(([\d.]+)\)').firstMatch(t);
    if (m != null) {
      return {
        'value': double.tryParse(m.group(1)!),
        'percent': double.tryParse(m.group(2)!),
      };
    }
    return null;
  }

  static Future<Map<String, PriceResponse>> fetchAllPrices() async {
    try {
      final res = await http.get(Uri.parse(_pageUrl), headers: {
        'User-Agent': 'Mozilla/5.0',
        'Accept': 'text/html',
        'Accept-Language': 'en-US,en;q=0.5',
      });
      if (res.statusCode != 200) return {};
      final doc = html_parser.parse(res.body);
      final rows = doc.querySelectorAll('div.price-box table tbody tr');
      final Map<String, PriceResponse> prices = {};
      for (final row in rows) {
        final cells = row.querySelectorAll('td');
        if (cells.length < 6) continue;
        final name = cells[0].text.trim();
        final key = _nameToKey[name];
        if (key == null) continue;
        var cur = _parsePrice(cells[1].text.trim());
        var high = _parsePrice(cells[2].text.trim());
        var low = _parsePrice(cells[3].text.trim());
        var yday = _parsePrice(cells[4].text.trim());
        String? dir;
        double? cVal;
        double? cPct;
        final span = cells[5].querySelector('span');
        if (span != null) {
          if (span.classes.contains('asc')) {
            dir = 'up';
          } else if (span.classes.contains('desc')) {
            dir = 'down';
          }
          final cd = _parseChange(span.text.trim());
          if (cd != null) {
            cVal = cd['value'];
            cPct = cd['percent'];
          }
        }
        const rialsMultiplier = 10.0;
        if (key != 'gold_ons') {
          cur = cur != null ? cur * rialsMultiplier : null;
          high = high != null ? high * rialsMultiplier : null;
          low = low != null ? low * rialsMultiplier : null;
          yday = yday != null ? yday * rialsMultiplier : null;
          if (cVal != null) cVal = cVal * rialsMultiplier;
        }
        prices[key] = PriceResponse(
          name: name,
          currentPrice: cur,
          high: high,
          low: low,
          yesterdayAvg: yday,
          change: Change(value: cVal, percent: cPct, direction: dir),
        );
      }
      return prices;
    } catch (_) {
      return {};
    }
  }
}

// -------------------- PriceProvider --------------------
class PriceProvider extends ChangeNotifier {
  Map<String, PriceResponse> _prices = {};
  Map<String, PriceResponse> _lastSavedPrices = {};
  DateTime _lastUpdated = DateTime(2000);
  Timer? _timer;
  final SharedPreferences _prefs;

  static const List<String> _priceKeys = [
    'gold_18',
    'gold_24',
    'gold_ons',
    'gold_mazneh',
    'coin_old',
    'coin_new',
    'coin_half',
    'coin_quarter',
    'coin_1g'
  ];

  Map<String, PriceResponse> get prices => UnmodifiableMapView(_prices);
  DateTime get lastUpdated => _lastUpdated;

  PriceProvider(this._prefs) {
    _loadSavedPrices();
    fetchPrices();
    startAutoUpdate();
  }

  void _loadSavedPrices() {
    _lastSavedPrices = {};
    for (var key in _priceKeys) {
      String? jsonStr = _prefs.getString('price_$key');
      if (jsonStr != null) {
        try {
          final json = jsonDecode(jsonStr);
          _lastSavedPrices[key] = PriceResponse.fromJson(json);
        } catch (_) {}
      }
    }
    if (_lastSavedPrices.isNotEmpty) {
      _prices = Map.from(_lastSavedPrices);
      int? t = _prefs.getInt('last_update');
      if (t != null) _lastUpdated = DateTime.fromMillisecondsSinceEpoch(t);
    }
  }

  Future<void> _savePrices(Map<String, PriceResponse> prices) async {
    for (var e in prices.entries) {
      final jsonStr = jsonEncode({
        'name': e.value.name,
        'current_price': e.value.currentPrice,
        'high': e.value.high,
        'low': e.value.low,
        'yesterday_avg': e.value.yesterdayAvg,
        'change': e.value.change != null
            ? {
                'value': e.value.change!.value,
                'percent': e.value.change!.percent,
                'direction': e.value.change!.direction,
              }
            : null,
      });
      await _prefs.setString('price_${e.key}', jsonStr);
    }
    await _prefs.setInt(
      'last_update',
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  void startAutoUpdate({int intervalSeconds = 300}) {
    _timer?.cancel();
    _timer = Timer.periodic(
      Duration(seconds: intervalSeconds),
      (_) => fetchPrices(),
    );
  }

  void setAutoUpdateInterval(int s) {
    startAutoUpdate(intervalSeconds: s);
  }

  Future<void> fetchPrices() async {
    final newPrices = await ApiService.fetchAllPrices();
    if (newPrices.isNotEmpty) {
      _prices = newPrices;
      _lastSavedPrices = Map.from(newPrices);
      _lastUpdated = DateTime.now();
      await _savePrices(newPrices);
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}