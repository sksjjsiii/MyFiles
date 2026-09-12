// ═══════════════════════════════════════════════════════════════════════════
//  نبض بازار | اپلیکیشن قیمت طلا، سکه، دلار، رمزارز و بورس
//  منطق استخراج داده دقیقاً بر اساس app.py (اسکرپر TGJU)
//  فونت: وزیر | زبان: فارسی | ناوبری: کریستال بلور (Blur)
// ═══════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';

// ═══════════════════════════════════════════════════════════════════════════
// ۱) ابزارها — اعداد فارسی، تقویم جلالی، فرمت قیمت
// ═══════════════════════════════════════════════════════════════════════════

const String _faDigits = '۰۱۲۳۴۵۶۷۸۹';
const String _enDigits = '0123456789';
const String _arDigits = '٠١٢٣٤٥٦٧٨٩';

String toFaDigits(String s) {
  final sb = StringBuffer();
  for (final rune in s.runes) {
    final ch = String.fromCharCode(rune);
    final ei = _enDigits.indexOf(ch);
    final ai = _arDigits.indexOf(ch);
    if (ei >= 0) { sb.write(_faDigits[ei]); }
    else if (ai >= 0) { sb.write(_faDigits[ai]); }
    else if (ch == ',') { sb.write('٬'); }
    else if (ch == '.') { sb.write('٫'); }
    else if (ch == '%') { sb.write('٪'); }
    else { sb.write(ch); }
  }
  return sb.toString();
}

String toEnDigits(String s) {
  var out = s;
  for (int i = 0; i < 10; i++) {
    out = out.replaceAll(_faDigits[i], _enDigits[i]).replaceAll(_arDigits[i], _enDigits[i]);
  }
  return out.replaceAll('٬', ',').replaceAll('،', ',').replaceAll('٫', '.').replaceAll('٪', '%');
}

String localizeDigits(BuildContext context, String s) {
  final fa = context.watch<SettingsProvider>().faDigits;
  return fa ? toFaDigits(s) : toEnDigits(s);
}

String formatNumber(num? v, {bool fa = true}) {
  if (v == null || v.isNaN) return '—';
  final a = v.abs();
  String pattern;
  if (a >= 1000) { pattern = '#,##0.##'; }
  else if (a >= 10) { pattern = '#,##0.###'; }
  else if (a >= 1) { pattern = '#,##0.####'; }
  else if (a >= 0.001) { pattern = '#,##0.######'; }
  else { pattern = '#,##0.########'; }
  var s = NumberFormat(pattern).format(v);
  if (fa) { s = toFaDigits(s); }
  return s;
}

String nf(BuildContext context, num? v) =>
    formatNumber(v, fa: context.watch<SettingsProvider>().faDigits);

String priceText(BuildContext context, double? rial) {
  if (rial == null) return '—';
  final s = context.watch<SettingsProvider>();
  final toman = s.priceUnitIndex == 1;
  final v = toman ? rial / 10 : rial;
  return '${formatNumber(v, fa: s.faDigits)} ${toman ? 'تومان' : 'ریال'}';
}

double? parseUserNumber(String? raw) {
  if (raw == null) return null;
  var t = toEnDigits(raw.trim()).replaceAll(' ', '');
  t = t.replaceAll(RegExp(r'[^\d.\-]'), '');
  return double.tryParse(t);
}

// ── تقویم جلالی ──────────────────────────────────────────────────────────────
List<int> gregorianToJalali(DateTime d) {
  const gdm = [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334];
  final gy = d.year, gm = d.month, gd = d.day;
  final gy2 = (gm > 2) ? (gy + 1) : gy;
  var days = 355666 + (365 * gy) + ((gy2 + 3) ~/ 4) - ((gy2 + 99) ~/ 100) +
      ((gy2 + 399) ~/ 400) + gd + gdm[gm - 1];
  var jy = -1595 + (33 * (days ~/ 12053));
  days %= 12053;
  jy += 4 * (days ~/ 1461);
  days %= 1461;
  if (days > 365) {
    jy += (days - 1) ~/ 365;
    days = (days - 1) % 365;
  }
  final jm = (days < 186) ? 1 + (days ~/ 31) : 7 + ((days - 186) ~/ 30);
  final jd = (days < 186) ? 1 + (days % 31) : 1 + ((days - 186) % 30);
  return [jy, jm, jd];
}

const List<String> _jMonthNames = [
  'فروردین', 'اردیبهشت', 'خرداد', 'تیر', 'مرداد', 'شهریور',
  'مهر', 'آبان', 'آذر', 'دی', 'بهمن', 'اسفند'
];
const List<String> _weekDays = ['دوشنبه', 'سه‌شنبه', 'چهارشنبه', 'پنجشنبه', 'جمعه', 'شنبه', 'یکشنبه'];

String jalaliDateStr(DateTime d) {
  final j = gregorianToJalali(d);
  return '${_weekDays[d.weekday - 1]} ${formatNumber(j[2])} ${_jMonthNames[j[1] - 1]} ${formatNumber(j[0])}';
}

String timeStr(DateTime d) {
  final h = d.hour.toString().padLeft(2, '0');
  final m = d.minute.toString().padLeft(2, '0');
  return toFaDigits('$h:$m');
}

Future<void> openUrl(String url) async {
  try {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {}
}

// ── تولید داده نمودار (پیاده‌روی تصادفی معکوس از قیمت فعلی) ────────────────
List<double> genHistory(String seed, double price, {int count = 60}) {
  final rnd = math.Random(seed.hashCode);
  final pts = <double>[price];
  double p = price;
  for (int i = 0; i < count - 1; i++) {
    p = p / (1 + (rnd.nextDouble() - 0.485) * 0.012);
    pts.insert(0, p);
  }
  return pts;
}

// ═══════════════════════════════════════════════════════════════════════════
// ۲) مدل‌های داده (مطابق خروجی tgju_data.json)
// ═══════════════════════════════════════════════════════════════════════════

class MarketItem {
  final String category;
  final String name;
  double? price;
  double? priceRial;
  double? priceUsd;
  double? rate;
  double? changeValue;
  double? changePercent;
  double? low;
  double? high;
  String? time;

  MarketItem({
    required this.category, required this.name,
    this.price, this.priceRial, this.priceUsd, this.rate,
    this.changeValue, this.changePercent, this.low, this.high, this.time,
  });

  double? get mainValue => price ?? rate ?? priceRial;
  String get key => '$category|$name';
}

class OfficeItem {
  final String name;
  final double? buy;
  final double? sell;
  final String? time;
  OfficeItem({required this.name, this.buy, this.sell, this.time});
}

class NewsItem {
  final String? id;
  final String title;
  final String url;
  final String? category;
  NewsItem({this.id, required this.title, required this.url, this.category});
}

class CalEvent {
  final String name;
  final String? previous;
  final String? forecast;
  CalEvent({required this.name, this.previous, this.forecast});
}

class AnalysisItem {
  final String title;
  final String url;
  AnalysisItem({required this.title, required this.url});
}

class AppData {
  List<MarketItem> summary = [];
  List<MarketItem> gold = [];
  List<MarketItem> coin = [];
  List<MarketItem> currency = [];
  List<MarketItem> crypto = [];
  List<MarketItem> digitalGold = [];
  List<MarketItem> forex = [];
  List<MarketItem> energy = [];
  List<MarketItem> metals = [];
  List<MarketItem> commodities = [];
  List<MarketItem> tehran = [];
  List<MarketItem> globalIndices = [];
  List<OfficeItem> offices = [];
  List<CalEvent> calendar = [];
  List<NewsItem> news = [];
  List<AnalysisItem> analyses = [];

  int get totalItems => summary.length + gold.length + coin.length + currency.length +
      crypto.length + digitalGold.length + forex.length + energy.length + metals.length +
      commodities.length + tehran.length + globalIndices.length + offices.length;
}

MarketItem _mi(String cat, String name,
    {double? price, double? cv, double? cp, double? low, double? high,
     String? time, double? rial, double? usd, double? rate}) {
  return MarketItem(category: cat, name: name, price: price, priceRial: rial,
      priceUsd: usd, rate: rate, changeValue: cv, changePercent: cp,
      low: low, high: high, time: time);
}

// ═══════════════════════════════════════════════════════════════════════════
// ۳) اسکرپر TGJU — پورت دقیق منطق app.py
// ═══════════════════════════════════════════════════════════════════════════

class TgjuScraper {
  static const String baseUrl = 'https://www.tgju.org';

  static const Set<String> headerKeywords = {
    'قیمت زنده', 'تغییر', 'کمترین', 'بیشترین', 'زمان', 'آخرین قیمت',
    'نرخ برابری', 'قیمت / دلار', 'ارزش', 'قیمت ریالی', 'قیمت دلاری',
    'خرید و فروش', 'خرید', 'فروش', 'صرافی', 'نرخ ارزها', 'دلار آمریکا',
    'یورو', 'پوند انگلیس', 'درهم امارات', 'یوان چین', 'لیر ترکیه',
    'سکه امامی', 'نیم سکه', 'ربع سکه', 'قبلی', 'پیش بینی',
    'نام', 'قیمت', 'واحد مبدا', 'واحد مقصد', 'نتیجه محاسبه',
    'نتیجه', 'مقدار', 'وزن طلا به گرم', 'اجرت', 'قیمت طلا (ریال)',
    'نوع سکه', 'قیمت دلار (ریال)', 'هزینه ضرب (ریال)'
  };

  static final List<RegExp> nonDataPatterns = [
    RegExp(r'^محاسبه گر'), RegExp(r'^حباب سنج'), RegExp(r'^آرشیو زمانی'),
    RegExp(r'^مبدل مقیاس'), RegExp(r'^واحد مبدا'), RegExp(r'^واحد مقصد'),
    RegExp(r'^نتیجه'), RegExp(r'^مقدار$'), RegExp(r'^نوع سکه:'),
    RegExp(r'^قیمت دلار \(ریال\):'), RegExp(r'^هزینه ضرب \(ریال\):'),
    RegExp(r'^وزن طلا به گرم'), RegExp(r'^اجرت'), RegExp(r'^شاخص دلار'),
  ];

  static const Set<String> badTitles = {'قیمت زنده طلا، سکه، دلار و ارز', 'خبر', ''};

  static String clean(String text) {
    var t = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    t = t.replaceAll('\u200c', ' ').replaceAll('\u200f', '').replaceAll('\u200e', '');
    return t.trim();
  }

  static String stripTags(String s) => s.replaceAll(RegExp(r'<[^>]*>'), '');

  static String decodeEntities(String s) => s
      .replaceAll('&amp;', '&').replaceAll('&lt;', '<').replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"').replaceAll('&#39;', "'").replaceAll('&nbsp;', ' ');

  static double? parseNumber(String? text) {
    if (text == null) return null;
    var t = text.trim().replaceAll(',', '').replaceAll('٬', '').replaceAll(' ', '');
    for (int i = 0; i < 10; i++) {
      t = t.replaceAll(_faDigits[i], '$_i').replaceAll(_arDigits[i], '$_i');
    }
    t = t.replaceAll(RegExp(r'[^\d.\-]'), '');
    return double.tryParse(t);
  }

  static Map<String, dynamic> parseChange(String? text) {
    final result = <String, dynamic>{'value': null, 'percent': null};
    if (text == null || text.trim().isEmpty || text.trim() == '-') return result;
    final t = text.trim();
    RegExpMatch? m;
    // الگوی ۱: (0.02%) 0.98
    m = RegExp(r'\((-?\d+\.?\d*)%\)\s*(-?[\d,٬\.]+)').firstMatch(t);
    if (m != null) {
      result['percent'] = double.tryParse(m.group(1)!);
      result['value'] = parseNumber(m.group(2));
      return result;
    }
    // الگوی ۲: 0.98 (0.02%)
    m = RegExp(r'(-?[\d,٬\.]+)\s*\((-?\d+\.?\d*)%\)').firstMatch(t);
    if (m != null) {
      result['value'] = parseNumber(m.group(1));
      result['percent'] = double.tryParse(m.group(2));
      return result;
    }
    // الگوی ۳: فقط درصد
    m = RegExp(r'\((-?\d+\.?\d*)%\)').firstMatch(t);
    if (m != null) {
      result['percent'] = double.tryParse(m.group(1));
      return result;
    }
    result['value'] = parseNumber(t);
    return result;
  }

  static bool isHeaderRow(List<String> cells) {
    if (cells.isEmpty) return true;
    int headerCount = 0;
    for (final cell in cells) {
      final c = cell.trim();
      if (c.isEmpty) continue;
      for (final kw in headerKeywords) {
        if (c.contains(kw)) { headerCount++; break; }
      }
    }
    final nonEmpty = cells.where((c) => c.trim().isNotEmpty).length;
    return nonEmpty > 0 && headerCount >= math.max(1, (nonEmpty * 0.5).floor());
  }

  static bool isNonDataRow(List<String> cells) {
    if (cells.isEmpty) return true;
    final first = cells.first.trim();
    for (final p in nonDataPatterns) {
      if (p.hasMatch(first)) return true;
    }
    if (cells.length == 1 && first.length > 100) return true;
    return false;
  }

  static String detectCategory(String title, List<String> headers) {
    final all = '$title ${headers.join(' ')}';
    if (['بورس تهران', 'شاخص كل', 'شاخص‌كل', 'فرابورس'].any(all.contains)) return 'tehran_stock_exchange';
    if (['بورس های جهانی', 'داوجونز', 'نزدک', 'نیکی', 'شانگهای'].any(all.contains)) return 'global_stock_indices';
    if (['نفت و انرژی', 'نفت سبک', 'نفت برنت', 'نفت اپک', 'بنزین', 'گاز طبیعی', 'زغال سنگ'].any(all.contains)) return 'energy_market';
    if (['فلزات پایه', 'آلومینیوم', 'نیکل', 'سرب', 'روی', 'مس', 'قلع'].any(all.contains)) return 'base_metals';
    if (['کالاها', 'پنبه', 'شکر', 'سویا', 'گندم', 'ذرت', 'برنج'].any(all.contains)) return 'commodities';
    if (['ارزهای دیجیتال', 'بیت کوین', 'اتریوم', 'لایت کوین', 'تتر', 'خرید و فروش'].any(all.contains)) return 'crypto_market';
    if (['طلای دیجیتال', 'تتر گلد', 'پکس گلد'].any(all.contains)) return 'digital_gold';
    if ((['صرافی', 'خرید', 'فروش'].any(all.contains)) && headers.join(' ').contains('صرافی')) return 'exchange_offices';
    if (['تقویم اقتصادی', 'قبلی', 'پیش بینی'].any(all.contains)) return 'economic_calendar';
    if (['برابری', 'eur/usd', 'gbp/usd', 'usd/jpy'].any((k) => all.toLowerCase().contains(k.toLowerCase()))) return 'forex_pairs';
    if (['سکه', 'حباب سکه', 'نیم سکه', 'ربع سکه', 'سکه گرمی'].any(all.contains)) return 'coin_market';
    if (['طلا', 'مثقال', 'آبشده', 'انس', 'نقره', 'صندوق طلا'].any(all.contains)) return 'gold_market';
    if (['ارز آزاد', 'دلار', 'یورو', 'پوند', 'درهم', 'لیر', 'فرانک'].any(all.contains)) return 'currency_market';
    return 'currency_market';
  }

  static List<List<String>> _extractRows(String tableHtml) {
    final rows = <List<String>>[];
    final trRe = RegExp(r'<tr[^>]*>([\s\S]*?)</tr>', caseSensitive: false);
    final tdRe = RegExp(r'<t[dh][^>]*>([\s\S]*?)</t[dh]>', caseSensitive: false);
    for (final tr in trRe.allMatches(tableHtml)) {
      final cells = <String>[];
      for (final td in tdRe.allMatches(tr.group(1)!)) {
        cells.add(clean(decodeEntities(stripTags(td.group(1)!))));
      }
      if (cells.isNotEmpty) rows.add(cells);
    }
    return rows;
  }

  static String _tableTitle(String html, int tableStart, List<List<String>> rows) {
    final before = html.substring(math.max(0, tableStart - 900), tableStart);
    final texts = RegExp(r'>([^<>{}]{3,80})<')
        .allMatches(before)
        .map((m) => clean(stripTags(m.group(1)!)))
        .where((t) => t.isNotEmpty && !badTitles.contains(t))
        .toList();
    if (texts.isNotEmpty) return texts.last;
    if (rows.isNotEmpty && rows.first.isNotEmpty && rows.first.first.length > 2) {
      return rows.first.first;
    }
    return 'جدول_بدون_عنوان';
  }

  static void _storeRows(AppData data, String category, List<List<String>> rows) {
    for (final row in rows) {
      if (row.isEmpty || row.first.trim().isEmpty) continue;
      final name = row.first.trim();
      if (name == '-' || name == 'نتیجه') continue;
      switch (category) {
        case 'tehran_stock_exchange':
          final ch = parseChange(row.length > 2 ? row[2] : null);
          data.tehran.add(_mi(category, name, price: parseNumber(row.length > 1 ? row[1] : null),
              cv: ch['value'], cp: ch['percent']));
          break;
        case 'global_stock_indices':
          final ch = parseChange(row.length > 2 ? row[2] : null);
          data.globalIndices.add(_mi(category, name, price: parseNumber(row.length > 1 ? row[1] : null),
              cv: ch['value'], cp: ch['percent']));
          break;
        case 'energy_market':
          final ch = parseChange(row.length > 2 ? row[2] : null);
          data.energy.add(_mi(category, name, price: parseNumber(row.length > 1 ? row[1] : null),
              cv: ch['value'], cp: ch['percent']));
          break;
        case 'base_metals':
          final ch = parseChange(row.length > 2 ? row[2] : null);
          data.metals.add(_mi(category, name, price: parseNumber(row.length > 1 ? row[1] : null),
              cv: ch['value'], cp: ch['percent']));
          break;
        case 'commodities':
          final ch = parseChange(row.length > 2 ? row[2] : null);
          data.commodities.add(_mi(category, name, price: parseNumber(row.length > 1 ? row[1] : null),
              cv: ch['value'], cp: ch['percent']));
          break;
        case 'crypto_market':
          final ch = parseChange(row.length > 3 ? row[3] : null);
          data.crypto.add(MarketItem(
            category: category, name: name,
            priceRial: parseNumber(row.length > 1 ? row[1] : null),
            priceUsd: parseNumber(row.length > 2 ? row[2] : null),
            changeValue: ch['value'], changePercent: ch['percent'],
            low: parseNumber(row.length > 4 ? row[4] : null),
            high: parseNumber(row.length > 5 ? row[5] : null),
            time: row.length > 6 ? row[6].trim() : null,
          ));
          break;
        case 'digital_gold':
          final ch = parseChange(row.length > 2 ? row[2] : null);
          data.digitalGold.add(_mi(category, name, price: parseNumber(row.length > 1 ? row[1] : null),
              cv: ch['value'], cp: ch['percent']));
          break;
        case 'forex_pairs':
          final ch = parseChange(row.length > 2 ? row[2] : null);
          data.forex.add(_mi(category, name, rate: parseNumber(row.length > 1 ? row[1] : null),
              cv: ch['value'], cp: ch['percent'],
              low: parseNumber(row.length > 3 ? row[3] : null),
              high: parseNumber(row.length > 4 ? row[4] : null),
              time: row.length > 5 ? row[5].trim() : null));
          break;
        case 'exchange_offices':
          data.offices.add(OfficeItem(
            name: name,
            buy: parseNumber(row.length > 1 ? row[1] : null),
            sell: parseNumber(row.length > 2 ? row[2] : null),
            time: row.length > 3 ? row[3].trim() : null,
          ));
          break;
        case 'economic_calendar':
          data.calendar.add(CalEvent(name: name,
              previous: row.length > 1 ? row[1].trim() : null,
              forecast: row.length > 2 ? row[2].trim() : null));
          break;
        default:
          final ch = parseChange(row.length > 2 ? row[2] : null);
          data.currency.add(_mi(category, name, price: parseNumber(row.length > 1 ? row[1] : null),
              cv: ch['value'], cp: ch['percent'],
              low: parseNumber(row.length > 3 ? row[3] : null),
              high: parseNumber(row.length > 4 ? row[4] : null),
              time: row.length > 5 ? row[5].trim() : null));
      }
    }
  }

  static Future<AppData> scrape() async {
    final data = AppData();
    final res = await http
        .get(Uri.parse(baseUrl), headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Accept-Language': 'fa-IR,fa;q=0.9,en-US;q=0.8,en;q=0.7',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        })
        .timeout(const Duration(seconds: 40));
    if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
    final html = utf8.decode(res.bodyBytes, allowMalformed: true);

    final tableRe = RegExp(r'<table[^>]*>([\s\S]*?)</table>', caseSensitive: false);
    final tables = tableRe.allMatches(html).toList();
    final consumed = <int>{};

    // ── ۱. شاخص یاب (خلاصه بازار) — مانند extract_summary_tickers ──
    for (final t in tables) {
      final rows = _extractRows(t.group(1)!);
      if (rows.length <= 3) continue;
      final firstJoined = rows.first.join(' ');
      final isTicker = ['سکه', 'طلا ۱۸', 'دلار', 'بورس', 'انس طلا'].any(firstJoined.contains);
      if (!isTicker) continue;
      for (final row in rows) {
        if (row.length < 5) continue;
        if (isHeaderRow(row) || isNonDataRow(row)) continue;
        final ch = parseChange(row.length > 2 ? row[2] : null);
        final price = parseNumber(row[1]);
        if (price == null) continue;
        data.summary.add(_mi('summary_tickers', row[0], price: price,
            cv: ch['value'], cp: ch['percent'],
            low: parseNumber(row.length > 3 ? row[3] : null),
            high: parseNumber(row.length > 4 ? row[4] : null),
            time: row.length > 5 ? row[5].trim() : null));
      }
      consumed.add(t.start);
    }

    // ── ۲. تمام جداول — مانند extract_all_tables ──
    for (final t in tables) {
      if (consumed.contains(t.start)) continue;
      final rows = _extractRows(t.group(1)!);
      if (rows.isEmpty) continue;
      final title = _tableTitle(html, t.start, rows);
      final headers = <String>[];
      final dataRows = <List<String>>[];
      bool headerFound = false;
      for (final row in rows) {
        if (!row.any((c) => c.trim().isNotEmpty)) continue;
        if (isNonDataRow(row)) continue;
        if (!headerFound && isHeaderRow(row)) {
          headers.addAll(row);
          headerFound = true;
          continue;
        }
        if (!headerFound) headerFound = true;
        if (headerFound && isHeaderRow(row)) continue;
        dataRows.add(row);
      }
      if (dataRows.isEmpty) continue;
      final category = detectCategory(title, headers);
      _storeRows(data, category, dataRows);
    }

    // ── ۳. اخبار — مانند extract_news ──
    final seen = <String>{};
    final aRe = RegExp(r'<a[^>]+href="([^"]+)"[^>]*>([\s\S]*?)</a>', caseSensitive: false);
    for (final a in aRe.allMatches(html)) {
      final href = a.group(1)!;
      if (!href.contains('/news/') || href.contains('/category/')) continue;
      final text = clean(decodeEntities(stripTags(a.group(2)!)));
      if (text.length <= 15) continue;
      final full = href.startsWith('http') ? href : baseUrl + href;
      if (seen.contains(full)) continue;
      seen.add(full);
      final id = RegExp(r'/news/(\d+)').firstMatch(full)?.group(1);
      data.news.add(NewsItem(id: id, title: text, url: full));
    }

    // ── ۴. تحلیل‌های تکنیکال — مانند extract_technical_analysis ──
    for (final a in aRe.allMatches(html)) {
      final href = a.group(1)!;
      if (!href.contains('/panel/technical/view/')) continue;
      final text = clean(decodeEntities(stripTags(a.group(2)!)));
      if (text.length <= 5) continue;
      final full = href.startsWith('http') ? href : baseUrl + href;
      data.analyses.add(AnalysisItem(title: text, url: full));
    }

    if (data.totalItems == 0) throw Exception('هیچ داده‌ای استخراج نشد');
    return data;
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ۴) داده‌های نمونه (آفلاین) — برگرفته از خروجی واقعی tgju_data.json
// ═══════════════════════════════════════════════════════════════════════════

AppData demoData() {
  final d = AppData();
  d.summary.addAll([
    _mi('summary_tickers', 'سکه', price: 2394950000, cv: 15150000, cp: 0.63, low: 2394500000, high: 2410100000, time: '۱۹:۵۹:۵۵'),
    _mi('summary_tickers', 'طلا ۱۸', price: 239168000, cv: 2646000, cp: 1.11, low: 238573000, high: 242174000, time: '۱۹:۵۹:۵۴'),
    _mi('summary_tickers', 'دلار', price: 2339000, cv: 20750, cp: 0.89, low: 2336600, high: 2370200, time: '۱۹:۵۹:۴۰'),
    _mi('summary_tickers', 'بورس', price: 7277555, cv: 155268, cp: 2.18, low: 7242923, high: 7277556, time: '۱۶:۴۵:۳۱'),
    _mi('summary_tickers', 'انس طلا', price: 4350.36, cv: 0.98, cp: 0.02, low: 4346.12, high: 4350.36, time: '۰۰:۵۶:۳۵'),
    _mi('summary_tickers', 'مثقال طلا', price: 1036040000, cv: 11450000, cp: 1.11, low: 1033450000, high: 1049050000, time: '۱۹:۵۹:۵۶'),
    _mi('summary_tickers', 'نفت برنت', price: 104.61, cv: 0.009, cp: 0.01, low: 104.313, high: 104.742, time: '۰۴:۵۱:۳۴'),
    _mi('summary_tickers', 'تتر', price: 2332950, cv: 36670, cp: 1.57, low: 2322560, high: 2383600, time: '۲۰:۴۴:۴۹'),
    _mi('summary_tickers', 'بیت کوین', price: 77392.76, cv: 30.75, cp: 0.04, low: 76986, high: 77487.4, time: '۲۰:۴۲:۳۸'),
  ]);
  d.gold.addAll([
    _mi('gold_market', 'انس طلا', price: 4350.36, cv: 0.98, cp: 0.02, low: 4346.12, high: 4350.36, time: '۰۰:۵۶:۳۵'),
    _mi('gold_market', 'انس نقره', price: 64.27, cv: 0.11, cp: 0.16, low: 64.27, high: 64.49, time: '۰۲:۵۱:۴۳'),
    _mi('gold_market', 'طلای 18 عیار', price: 239168000, cv: 2646000, cp: 1.11, low: 238573000, high: 242174000, time: '۱۹:۵۹:۵۴'),
    _mi('gold_market', 'طلای 24 عیار', price: 318888000, cv: 3527000, cp: 1.11, low: 318094000, high: 322895000, time: '۱۹:۵۹:۵۴'),
    _mi('gold_market', 'طلای دست دوم', price: 235979450, cv: 2610280, cp: 1.11, low: 235391800, high: 238945060, time: '۱۹:۵۹:۵۴'),
    _mi('gold_market', 'گرم نقره ۹۹۹', price: 5097700, cv: 119300, cp: 2.34, low: 5093800, high: 5219300, time: '۲۰:۴۷:۲۲'),
    _mi('gold_market', 'مثقال طلا', price: 1036040000, cv: 11450000, cp: 1.11, low: 1033450000, high: 1049050000, time: '۱۹:۵۹:۵۶'),
    _mi('gold_market', 'آبشده نقدی', price: 1042790000, cv: 8050000, cp: 0.77, low: 1038050000, high: 1046050000, time: '۱۹:۵۹:۵۶'),
    _mi('gold_market', 'صندوق طلای عیار', price: 652941, cv: 7259, cp: 1.11, low: 514215, high: 661736, time: '۱۸:۴۱:۳۰'),
    _mi('gold_market', 'صندوق طلای لوتوس', price: 1658600, cv: 11500, cp: 0.69, low: 1328000, high: 1685555, time: '۱۸:۴۱:۲۸'),
  ]);
  d.coin.addAll([
    _mi('coin_market', 'سکه امامی', price: 2394950000, cv: 15150000, cp: 0.63, low: 2394500000, high: 2410100000, time: '۱۹:۵۹:۵۵'),
    _mi('coin_market', 'سکه بهار آزادی', price: 2352800000, cv: 10750000, cp: 0.46, low: 2340300000, high: 2362900000, time: '۱۹:۵۹:۵۶'),
    _mi('coin_market', 'نیم سکه', price: 1220000000, cv: 10000000, cp: 0.82, low: 1220000000, high: 1220000000, time: '۱۱:۰۰:۴۹'),
    _mi('coin_market', 'ربع سکه', price: 650000000, cv: 5000000, cp: 0.77, low: 650000000, high: 650000000, time: '۱۱:۰۰:۴۹'),
    _mi('coin_market', 'سکه گرمی', price: 340000000, cv: 10000000, cp: 2.94, low: 340000000, high: 340000000, time: '۱۱:۰۰:۴۹'),
    _mi('coin_market', 'حباب سکه امامی', price: 6610000, cv: 7310000, cp: 110.59, low: 10000, high: 38870000, time: '۱۹:۵۹:۵۴'),
    _mi('coin_market', 'حباب سکه بهار آزادی', price: 49160000, cv: 11310000, cp: 23.01, low: 46560000, high: 81320000, time: '۱۹:۵۹:۵۴'),
    _mi('coin_market', 'حباب نیم سکه', price: 19580000, cv: 1170000, cp: 6.36, low: 3590000, high: 20910000, time: '۱۹:۵۹:۴۴'),
    _mi('coin_market', 'حباب ربع سکه', price: 49770000, cv: 590000, cp: 1.2, low: 41770000, high: 50430000, time: '۱۹:۵۹:۴۴'),
    _mi('coin_market', 'حباب سکه گرمی', price: 44770000, cv: 7250000, cp: 16.19, low: 40830000, high: 52630000, time: '۱۹:۵۹:۴۴'),
  ]);
  d.currency.addAll([
    _mi('currency_market', 'دلار', price: 2339000, cv: 20750, cp: 0.89, low: 2336600, high: 2370200, time: '۱۹:۵۹:۴۰'),
    _mi('currency_market', 'یورو', price: 2722600, cv: 25000, cp: 0.92, low: 2720100, high: 2758900, time: '۱۹:۵۹:۴۴'),
    _mi('currency_market', 'درهم امارات', price: 640760, cv: 5770, cp: 0.9, low: 640180, high: 649280, time: '۱۹:۵۹:۴۴'),
    _mi('currency_market', 'پوند انگلیس', price: 3172200, cv: 23200, cp: 0.73, low: 3169300, high: 3214500, time: '۱۹:۵۹:۴۴'),
    _mi('currency_market', 'لیر ترکیه', price: 49400, cv: 200, cp: 0.4, low: 49400, high: 50100, time: '۱۹:۵۱:۳۲'),
    _mi('currency_market', 'فرانک سوئیس', price: 2879100, cv: 37700, cp: 1.31, low: 2876400, high: 2917300, time: '۱۹:۵۹:۴۴'),
    _mi('currency_market', 'یوان چین', price: 352100, cv: 3200, cp: 0.91, low: 351800, high: 356800, time: '۱۹:۵۹:۴۴'),
    _mi('currency_market', 'ین ژاپن', price: 1544000, cv: 7500, cp: 0.49, low: 1537000, high: 1544000, time: '۱۶:۴۷:۴۵'),
    _mi('currency_market', 'دلار کانادا', price: 1690500, cv: 21600, cp: 1.28, low: 1688900, high: 1713000, time: '۱۹:۵۹:۴۴'),
    _mi('currency_market', 'دینار عراق', price: 1529, cv: 14, cp: 0.92, low: 1497, high: 1554, time: '۱۹:۵۹:۴۴'),
    _mi('currency_market', 'لیر سوریه', price: 19139, cv: 176, cp: 0.92, low: 19121, high: 19394, time: '۱۹:۵۹:۴۴'),
    _mi('currency_market', 'افغانی', price: 36280, cv: 310, cp: 0.85, low: 36250, high: 37060, time: '۱۹:۵۹:۴۴'),
    _mi('currency_market', 'ریال عربستان', price: 624460, cv: 5630, cp: 0.9, low: 623890, high: 632780, time: '۱۹:۵۹:۴۴'),
    _mi('currency_market', 'دینار کویت', price: 7614300, cv: 66300, cp: 0.87, low: 7607300, high: 7715800, time: '۱۹:۵۹:۴۴'),
    _mi('currency_market', 'منات آذربایجان', price: 1380800, cv: 12400, cp: 0.9, low: 1379600, high: 1399200, time: '۱۹:۵۹:۴۴'),
  ]);
  d.crypto.addAll([
    MarketItem(category: 'crypto_market', name: 'بیت کوین', priceRial: 180251974000, priceUsd: 77321.54, changeValue: 101.97, changePercent: 0.13, low: 76986, high: 77487.4, time: '۲۰:۵۱:۱۸'),
    MarketItem(category: 'crypto_market', name: 'اتریوم', priceRial: 5899684400, priceUsd: 2530.75, changeValue: 9.29, changePercent: 0.37, low: 2508.22, high: 2544.35, time: '۲۰:۵۱:۱۸'),
    MarketItem(category: 'crypto_market', name: 'لایت کوین', priceRial: 125791600, priceUsd: 53.96, changeValue: 0.31, changePercent: 0.58, low: 52.96, high: 54.23, time: '۲۰:۵۱:۱۹'),
    MarketItem(category: 'crypto_market', name: 'بیت کوین کش', priceRial: 532958900, priceUsd: 228.62, changeValue: 0.98, changePercent: 0.43, low: 226.11, high: 232.01, time: '۲۰:۵۱:۱۹'),
    MarketItem(category: 'crypto_market', name: 'تتر', priceRial: 2330990, priceUsd: 1, changeValue: 0, changePercent: 0, low: 1, high: 1, time: '۰۹:۳۰:۳۸'),
    MarketItem(category: 'crypto_market', name: 'بایننس کوین', priceRial: 1706811400, priceUsd: 732.16, changeValue: 5.64, changePercent: 0.78, low: 723.36, high: 738.97, time: '۲۰:۴۷:۳۷'),
    MarketItem(category: 'crypto_market', name: 'ریپل', priceRial: 3193700, priceUsd: 1.37, changeValue: 0.01, changePercent: 0.74, low: 1.35, high: 1.37, time: '۱۰:۵۱:۱۰'),
    MarketItem(category: 'crypto_market', name: 'دوج کوین', priceRial: 198200, priceUsd: 0.08502478, changeValue: 0.0005, changePercent: 0.59, low: 0.00005495, high: 0.0852842, time: '۲۰:۵۱:۱۹'),
    MarketItem(category: 'crypto_market', name: 'سولانا', priceRial: 237969000, priceUsd: 102.08, changeValue: 0.55, changePercent: 0.54, low: 101.51, high: 102.97, time: '۲۰:۵۱:۱۸'),
    MarketItem(category: 'crypto_market', name: 'کاردانو', priceRial: 485500, priceUsd: 0.20824766, changeValue: 0.0018, changePercent: 0.86, low: 0.20451821, high: 0.20948667, time: '۲۰:۵۱:۱۹'),
    MarketItem(category: 'crypto_market', name: 'شیبا اینو', priceRial: 12, priceUsd: 0.0000053, changeValue: 0, changePercent: 2.32, low: 0.00000001, high: 0.00000538, time: '۲۰:۵۱:۱۹'),
  ]);
  d.digitalGold.addAll([
    _mi('digital_gold', 'تتر گلد', price: 4351.11, cv: 0.05, cp: 0.0),
    _mi('digital_gold', 'پکس گلد', price: 4356.01, cv: 0.81, cp: 0.02),
    _mi('digital_gold', 'ماتریکس داک گلد', price: 4346.37, cv: 4.2, cp: 0.1),
    _mi('digital_gold', 'کامتک گلد', price: 138.63, cv: 1.21, cp: 0.87),
  ]);
  d.forex.addAll([
    _mi('forex_pairs', 'EUR/USD', rate: 1.1598, cv: 0.0005, cp: 0.04, low: 1.1591, high: 1.1598, time: '۰۰:۴۵:۳۸'),
    _mi('forex_pairs', 'GBP/USD', rate: 1.3525, cv: 0.0001, cp: 0.01, low: 1.3523, high: 1.3527, time: '۰۰:۴۴:۲۶'),
    _mi('forex_pairs', 'USD/JPY', rate: 153.5, cv: 0.17, cp: 0.11, low: 153.48, high: 153.73, time: '۰۰:۵۵:۵۷'),
    _mi('forex_pairs', 'USD/CHF', rate: 0.8163, cv: 0.0002, cp: 0.02, low: 0.8162, high: 0.8167, time: '۰۰:۴۶:۴۸'),
    _mi('forex_pairs', 'USD/TRY', rate: 48.3822, cv: 0.2058, cp: 0.43, low: 48.351, high: 48.584, time: '۰۰:۵۵:۵۹'),
    _mi('forex_pairs', 'USD/SAR', rate: 3.7555, cv: 0, cp: 0, low: 3.7535, high: 3.7555, time: '۲۰ شهریور'),
  ]);
  d.energy.addAll([
    _mi('energy_market', 'نفت سبک', price: 102.26, cv: 0, cp: 0),
    _mi('energy_market', 'نفت برنت', price: 104.61, cv: 0.009, cp: 0.01),
    _mi('energy_market', 'نفت اپک', price: 114.89, cv: 0, cp: 0),
    _mi('energy_market', 'بنزین (RBOB)', price: 3.3072, cv: 0.0139, cp: 0.42),
    _mi('energy_market', 'گاز طبیعی', price: 2.831, cv: 0.0062, cp: 0.22),
    _mi('energy_market', 'زغال سنگ', price: 85.52, cv: 0.43, cp: 0.5),
  ]);
  d.metals.addAll([
    _mi('base_metals', 'آلومینیوم', price: 3256.65, cv: 0, cp: 0),
    _mi('base_metals', 'نیکل (تن)', price: 16432, cv: 93, cp: 0.57),
    _mi('base_metals', 'سرب (تن)', price: 1892.93, cv: 0, cp: 0),
    _mi('base_metals', 'روی (تن)', price: 3865.55, cv: 0, cp: 0),
    _mi('base_metals', 'مس (تن)', price: 6.4695, cv: 0.0018, cp: 0.03),
    _mi('base_metals', 'قلع', price: 54034, cv: 310, cp: 0.57),
  ]);
  d.commodities.addAll([
    _mi('commodities', 'پنبه', price: 86.06, cv: 0.13, cp: 0.15),
    _mi('commodities', 'شکر', price: 18.15, cv: 0, cp: 0),
    _mi('commodities', 'سویا', price: 1280.25, cv: 15.75, cp: 1.23),
    _mi('commodities', 'گندم', price: 707, cv: 4, cp: 0.57),
    _mi('commodities', 'ذرت', price: 510.25, cv: 0.75, cp: 0.15),
    _mi('commodities', 'برنج', price: 15.6, cv: 0.055, cp: 0.35),
  ]);
  d.tehran.addAll([
    _mi('tehran_stock_exchange', 'شاخص کل', price: 7277555, cv: 155268, cp: 2.18),
    _mi('tehran_stock_exchange', 'شاخص فرابورس', price: 56281.59, cv: 1062.01, cp: 1.92),
    _mi('tehran_stock_exchange', 'شاخص ۳۰ شرکت بزرگ', price: 527353.03, cv: 12541.15, cp: 2.43),
  ]);
  d.globalIndices.addAll([
    _mi('global_stock_indices', 'داوجونز', price: 52550.45, cv: 14, cp: 0.03),
    _mi('global_stock_indices', 'اس اند پی ۵۰۰', price: 7656.98, cv: 0.33, cp: 0),
    _mi('global_stock_indices', 'نزدک', price: 26333.0352, cv: 27.2382, cp: 0.1),
    _mi('global_stock_indices', 'نیکی ژاپن', price: 64011.3398, cv: 0, cp: 0),
    _mi('global_stock_indices', 'شانگهای چین', price: 3888.1106, cv: 46.293, cp: 1.19),
    _mi('global_stock_indices', 'دکس آلمان', price: 25568.56, cv: 0.0005, cp: 0),
  ]);
  d.offices.addAll([
    OfficeItem(name: 'والکس', buy: 2340820, sell: 2341000, time: '۱۸:۵۱'),
    OfficeItem(name: 'نوبیتکس', buy: 2337090, sell: 2339850, time: '۱۸:۵۲'),
    OfficeItem(name: 'آبان تتر', buy: 2324420, sell: 2341240, time: '۱۸:۵۰'),
    OfficeItem(name: 'بیت پین', buy: null, sell: 2336190, time: '۱۸:۵۲'),
    OfficeItem(name: 'ارزپایا', buy: 2345940, sell: 2348300, time: '۱۸:۰۷'),
  ]);
  d.calendar.addAll([
    CalEvent(name: '03:30 CN New Yuan Loans', previous: 'CNY-340B', forecast: 'CNY 450.0B'),
    CalEvent(name: '03:30 CN M2 Money Supply YoY', previous: '7.7%', forecast: '-'),
    CalEvent(name: '10:30 IN Inflation Rate YoY', previous: '4.45%', forecast: '-'),
  ]);
  d.news.addAll([
    NewsItem(id: '3886031', title: 'بازگشت بیت کوین پیش از نشست فدرال رزرو؛ آرامش موقت یا نشانه صعود دوباره؟', url: 'https://www.tgju.org/news/3886031'),
    NewsItem(id: '3886540', title: 'هشدار استراتژیست شواب: افزایش نرخ بهره فدرال رزرو در هفته آینده محتمل شد', url: 'https://www.tgju.org/news/3886540'),
    NewsItem(id: '3886536', title: 'قیمت طلا با وجود داده تورمی داغ، به دنبال بازگشت به ۴٬۴۷۰ دلار', url: 'https://www.tgju.org/news/3886536'),
    NewsItem(id: '3886027', title: 'شاخص کل بورس با جهش ۱.۸۹ درصدی به کانال ۷.۲ میلیون واحد رسید', url: 'https://www.tgju.org/news/3886027'),
    NewsItem(id: '3886203', title: 'یورو ۲۷۵ هزار تومانی شد؛ بازار در آستانه ادامه صعود یا اصلاح؟', url: 'https://www.tgju.org/news/3886203'),
    NewsItem(id: '3886415', title: 'شکست ۹۰ دلار معادله نفت را تغییر داد؛ WTI در مسیر ۱۰۰ دلار؟', url: 'https://www.tgju.org/news/3886415'),
  ]);
  d.analyses.addAll([
    AnalysisItem(title: 'مثقال طلا ۲۱ شهریور', url: 'https://www.tgju.org/panel/technical/view/26123'),
    AnalysisItem(title: 'انس طلا ۲۱ شهریور', url: 'https://www.tgju.org/panel/technical/view/26121'),
    AnalysisItem(title: 'بیت کوین ۱۹ شهریور', url: 'https://www.tgju.org/panel/technical/view/26109'),
    AnalysisItem(title: 'دلار ۱۹ شهریور', url: 'https://www.tgju.org/panel/technical/view/26106'),
  ]);
  return d;
}

// ═══════════════════════════════════════════════════════════════════════════
// ۵) ارائه‌دهنده تنظیمات — شخصی‌سازی کامل
// ═══════════════════════════════════════════════════════════════════════════

class SettingsProvider extends ChangeNotifier {
  static const List<int> palette = [
    0xFF6366F1, 0xFF8B5CF6, 0xFFEC4899, 0xFFEF4444, 0xFFF59E0B, 0xFF10B981,
    0xFF14B8A6, 0xFF0EA5E9, 0xFF3B82F6, 0xFF64748B, 0xFFB45309, 0xFF065F46,
  ];

  SharedPreferences? _prefs;

  int themeModeIndex = 0; // 0=سیستم 1=روشن 2=تاریک
  int accentValue = 0xFF6366F1;
  int menuColorValue = 0xFF6366F1;
  double menuWidthPercent = 92;
  double menuBottomPadding = 16;
  double menuBlur = 20;
  double menuOpacity = 0.15;
  double menuRadius = 32;
  double navIconSize = 24;
  double navHeight = 72;
  bool showNavLabels = true;
  double cardRadius = 24;
  double cardElevation = 2;
  bool glassCards = true;
  bool gradientHeader = true;
  double fontScale = 1.0;
  bool animations = true;
  bool compact = false;
  bool faDigits = true;
  bool showPercent = true;
  bool showChangeValue = true;
  bool showTime = true;
  bool showSparkline = true;
  int priceUnitIndex = 1; // 0=ریال 1=تومان
  int positiveValue = 0xFF10B981;
  int negativeValue = 0xFFEF4444;
  int refreshMinutes = 5;
  bool onlineMode = true;
  List<String> tabOrder = ['home', 'gold', 'currency', 'crypto', 'charts', 'settings'];
  List<String> hiddenTabs = [];
  String defaultTab = 'home';
  Set<String> favorites = {};
  List<Map<String, dynamic>> alerts = [];

  Color get accent => Color(accentValue);
  Color get menuColor => Color(menuColorValue);
  Color get positive => Color(positiveValue);
  Color get negative => Color(negativeValue);

  bool isDarkMode(Brightness platform) =>
      themeModeIndex == 2 || (themeModeIndex == 0 && platform == Brightness.dark);

  List<String> get visibleTabs =>
      tabOrder.where((id) => !hiddenTabs.contains(id)).toList();

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    final p = _prefs!;
    themeModeIndex = p.getInt('themeMode') ?? 0;
    accentValue = p.getInt('accent') ?? 0xFF6366F1;
    menuColorValue = p.getInt('menuColor') ?? accentValue;
    menuWidthPercent = p.getDouble('menuWidth') ?? 92;
    menuBottomPadding = p.getDouble('menuBottomPad') ?? 16;
    menuBlur = p.getDouble('menuBlur') ?? 20;
    menuOpacity = p.getDouble('menuOpacity') ?? 0.15;
    menuRadius = p.getDouble('menuRadius') ?? 32;
    navIconSize = p.getDouble('navIconSize') ?? 24;
    navHeight = p.getDouble('navHeight') ?? 72;
    showNavLabels = p.getBool('showLabels') ?? true;
    cardRadius = p.getDouble('cardRadius') ?? 24;
    cardElevation = p.getDouble('cardElevation') ?? 2;
    glassCards = p.getBool('glass') ?? true;
    gradientHeader = p.getBool('gradientHeader') ?? true;
    fontScale = p.getDouble('fontScale') ?? 1.0;
    animations = p.getBool('animations') ?? true;
    compact = p.getBool('compact') ?? false;
    faDigits = p.getBool('faDigits') ?? true;
    showPercent = p.getBool('showPercent') ?? true;
    showChangeValue = p.getBool('showChangeValue') ?? true;
    showTime = p.getBool('showTime') ?? true;
    showSparkline = p.getBool('showSparkline') ?? true;
    priceUnitIndex = p.getInt('priceUnit') ?? 1;
    positiveValue = p.getInt('positive') ?? 0xFF10B981;
    negativeValue = p.getInt('negative') ?? 0xFFEF4444;
    refreshMinutes = p.getInt('refreshMin') ?? 5;
    onlineMode = p.getBool('onlineMode') ?? true;
    tabOrder = p.getStringList('tabOrder') ?? tabOrder;
    hiddenTabs = p.getStringList('hiddenTabs') ?? [];
    defaultTab = p.getString('defaultTab') ?? 'home';
    favorites = (p.getStringList('favorites') ?? []).toSet();
    final rawAlerts = p.getStringList('alerts') ?? [];
    alerts = rawAlerts
        .map((e) => Map<String, dynamic>.from(jsonDecode(e) as Map))
        .toList();
    notifyListeners();
  }

  void _save(VoidCallback fn) {
    fn();
    notifyListeners();
    final p = _prefs;
    if (p == null) return;
    p.setInt('themeMode', themeModeIndex);
    p.setInt('accent', accentValue);
    p.setInt('menuColor', menuColorValue);
    p.setDouble('menuWidth', menuWidthPercent);
    p.setDouble('menuBottomPad', menuBottomPadding);
    p.setDouble('menuBlur', menuBlur);
    p.setDouble('menuOpacity', menuOpacity);
    p.setDouble('menuRadius', menuRadius);
    p.setDouble('navIconSize', navIconSize);
    p.setDouble('navHeight', navHeight);
    p.setBool('showLabels', showNavLabels);
    p.setDouble('cardRadius', cardRadius);
    p.setDouble('cardElevation', cardElevation);
    p.setBool('glass', glassCards);
    p.setBool('gradientHeader', gradientHeader);
    p.setDouble('fontScale', fontScale);
    p.setBool('animations', animations);
    p.setBool('compact', compact);
    p.setBool('faDigits', faDigits);
    p.setBool('showPercent', showPercent);
    p.setBool('showChangeValue', showChangeValue);
    p.setBool('showTime', showTime);
    p.setBool('showSparkline', showSparkline);
    p.setInt('priceUnit', priceUnitIndex);
    p.setInt('positive', positiveValue);
    p.setInt('negative', negativeValue);
    p.setInt('refreshMin', refreshMinutes);
    p.setBool('onlineMode', onlineMode);
    p.setStringList('tabOrder', tabOrder);
    p.setStringList('hiddenTabs', hiddenTabs);
    p.setString('defaultTab', defaultTab);
    p.setStringList('favorites', favorites.toList());
    p.setStringList('alerts', alerts.map((a) => jsonEncode(a)).toList());
  }

  void set(void Function(SettingsProvider s) mutate) => _save(() => mutate(this));

  bool isFavorite(String key) => favorites.contains(key);
  void toggleFavorite(String key) => _save(() {
        favorites.contains(key) ? favorites.remove(key) : favorites.add(key);
      });

  bool hasAlert(String key) => alerts.any((a) => a['key'] == key);
  Map<String, dynamic>? alertFor(String key) {
    for (final a in alerts) {
      if (a['key'] == key) return a;
    }
    return null;
  }

  void saveAlert(String key, String name, double? above, double? below) => _save(() {
        alerts.removeWhere((a) => a['key'] == key);
        if (above != null || below != null) {
          alerts.add({'key': key, 'name': name, 'above': above, 'below': below});
        }
      });

  void removeAlert(String key) => _save(() => alerts.removeWhere((a) => a['key'] == key));

  void reorderTabs(int oldIndex, int newIndex) => _save(() {
        var ni = newIndex;
        if (oldIndex < ni) ni -= 1;
        final item = tabOrder.removeAt(oldIndex);
        tabOrder.insert(ni, item);
      });

  void toggleTabVisible(String id) {
    if (id == 'home' || id == 'settings') return;
    _save(() {
      hiddenTabs.contains(id) ? hiddenTabs.remove(id) : hiddenTabs.add(id);
    });
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ۶) ارائه‌دهنده داده بازار
// ═══════════════════════════════════════════════════════════════════════════

class MarketProvider extends ChangeNotifier {
  final SettingsProvider settings;
  MarketProvider(this.settings);

  bool loading = true;
  bool online = false;
  DateTime? lastUpdate;
  String? error;
  AppData data = AppData();
  final List<String> alertMessages = [];
  Timer? _timer;

  List<MarketItem> get allItems => [
        ...data.summary, ...data.gold, ...data.coin, ...data.currency,
        ...data.crypto, ...data.forex, ...data.energy, ...data.metals,
        ...data.commodities, ...data.tehran, ...data.globalIndices,
        ...data.digitalGold,
      ];

  List<MarketItem> get topMovers {
    final pool = [...data.gold, ...data.coin, ...data.currency, ...data.crypto]
        .where((e) => e.changePercent != null)
        .toList();
    pool.sort((a, b) => (b.changePercent ?? 0).compareTo(a.changePercent ?? 0));
    return pool;
  }

  Future<void> load({bool forceDemo = false}) async {
    loading = true;
    notifyListeners();
    AppData? d;
    bool isOnline = false;
    String? err;
    if (settings.onlineMode && !forceDemo) {
      try {
        d = await TgjuScraper.scrape();
        isOnline = true;
      } catch (e) {
        err = 'اتصال به سرور برقرار نشد';
      }
    }
    if (d == null) {
      d = demoData();
      if (!settings.onlineMode) err = 'حالت آفلاین فعال است';
    }
    data = d;
    online = isOnline;
    error = err;
    loading = false;
    lastUpdate = DateTime.now();
    _checkAlerts();
    notifyListeners();
  }

  void _checkAlerts() {
    if (settings.alerts.isEmpty) return;
    final triggered = <Map<String, dynamic>>[];
    for (final rule in List<Map<String, dynamic>>.from(settings.alerts)) {
      final item = allItems.where((i) => i.key == rule['key']).firstOrNull;
      if (item == null) continue;
      final v = item.mainValue;
      if (v == null) continue;
      final above = (rule['above'] as num?)?.toDouble();
      final below = (rule['below'] as num?)?.toDouble();
      if (above != null && v >= above) {
        alertMessages.add('🔔 «${rule['name']}» به ${formatNumber(v, fa: settings.faDigits)} ریال رسید (آستانه: ${formatNumber(above, fa: settings.faDigits)})');
        triggered.add(rule);
      } else if (below != null && v <= below) {
        alertMessages.add('🔔 «${rule['name']}» به ${formatNumber(v, fa: settings.faDigits)} ریال کاهش یافت (آستانه: ${formatNumber(below, fa: settings.faDigits)})');
        triggered.add(rule);
      }
    }
    for (final t in triggered) {
      settings.removeAlert(t['key'] as String);
    }
  }

  void clearAlertMessages() => alertMessages.clear();

  void startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => _maybeRefresh());
  }

  void _maybeRefresh() {
    if (!settings.onlineMode || loading) return;
    final interval = Duration(minutes: settings.refreshMinutes);
    if (lastUpdate == null || DateTime.now().difference(lastUpdate!) >= interval) {
      load();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

// ═══════════════════════════════════════════════════════════════════════════
// ۷) پوسته و تم
// ═══════════════════════════════════════════════════════════════════════════

ThemeData buildAppTheme(SettingsProvider s, Brightness platform) {
  final dark = s.isDarkMode(platform);
  final scheme = ColorScheme.fromSeed(
      seedColor: s.accent, brightness: dark ? Brightness.dark : Brightness.light);
  return ThemeData(
    useMaterial3: true,
    fontFamily: 'Vazir',
    colorScheme: scheme,
    scaffoldBackgroundColor: dark ? const Color(0xFF0B0F1C) : const Color(0xFFF1F4FB),
    appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent, elevation: 0, foregroundColor: scheme.onSurface),
    dividerColor: Colors.transparent,
    splashColor: s.accent.withOpacity(0.08),
    highlightColor: Colors.transparent,
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: dark ? const Color(0xFF1E2438) : Colors.white,
      contentTextStyle: TextStyle(
          fontFamily: 'Vazir', fontSize: 13, color: dark ? Colors.white70 : Colors.black87),
    ),
    listTileTheme: ListTileThemeData(iconColor: scheme.onSurfaceVariant),
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
  ));
  final settings = SettingsProvider();
  await settings.init();
  runApp(TGJUApp(settings: settings));
}

class TGJUApp extends StatelessWidget {
  final SettingsProvider settings;
  const TGJUApp({super.key, required this.settings});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsProvider>.value(value: settings),
        ChangeNotifierProvider<MarketProvider>(
            create: (_) => MarketProvider(settings)..load()..startTimer()),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, s, _) {
          final theme = buildAppTheme(s, MediaQuery.platformBrightnessOf(context));
          return MaterialApp(
            title: 'نبض بازار',
            debugShowCheckedModeBanner: false,
            theme: theme,
            builder: (context, child) {
              return Directionality(
                textDirection: TextDirection.rtl,
                child: MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(s.fontScale)),
                  child: child ?? const SizedBox(),
                ),
              );
            },
            home: const MainScreen(),
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ۸) تعریف تب‌ها
// ═══════════════════════════════════════════════════════════════════════════

class TabDef {
  final String id;
  final String label;
  final IconData icon;
  const TabDef(this.id, this.label, this.icon);
}

const Map<String, TabDef> kTabs = {
  'home': TabDef('home', 'خانه', Icons.home_rounded),
  'gold': TabDef('gold', 'طلا و سکه', Icons.monetization_on_rounded),
  'currency': TabDef('currency', 'ارز', Icons.account_balance_wallet_rounded),
  'crypto': TabDef('crypto', 'رمزارز', Icons.currency_bitcoin_rounded),
  'charts': TabDef('charts', 'نمودارها', Icons.insights_rounded),
  'settings': TabDef('settings', 'تنظیمات', Icons.settings_rounded),
};

// ═══════════════════════════════════════════════════════════════════════════
// ۹) صفحه اصلی + نوار ناوبری بلور (مثال شما)
// ═══════════════════════════════════════════════════════════════════════════

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  String _currentTab = 'home';
  Offset _slideBegin = const Offset(0.06, 0);
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      final s = context.read<SettingsProvider>();
      if (s.visibleTabs.contains(s.defaultTab)) _currentTab = s.defaultTab;
    }
  }

  void _onTabSelected(List<String> ids, int index) {
    final newId = ids[index];
    if (newId == _currentTab) return;
    final oldIndex = ids.indexOf(_currentTab);
    _slideBegin = index > oldIndex
        ? const Offset(0.06, 0)
        : const Offset(-0.06, 0);
    setState(() => _currentTab = newId);
  }

  Widget _screenFor(String id) {
    switch (id) {
      case 'gold': return const GoldScreen();
      case 'currency': return const CurrencyScreen();
      case 'crypto': return const CryptoScreen();
      case 'charts': return const ChartsScreen();
      case 'settings': return const SettingsScreen();
      default: return const HomeScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final market = context.watch<MarketProvider>();

    // نمایش هشدارهای قیمت
    if (market.alertMessages.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final msgs = List<String>.from(market.alertMessages);
        market.clearAlertMessages();
        if (!mounted) return;
        for (final m in msgs) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
        }
      });
    }

    final ids = settings.visibleTabs;
    if (!ids.contains(_currentTab)) _currentTab = ids.first;
    final selectedIndex = ids.indexOf(_currentTab);
    final dark = settings.isDarkMode(MediaQuery.platformBrightnessOf(context));
    final screenWidth = MediaQuery.of(context).size.width;
    final widthFactor = (settings.menuWidthPercent / 100).clamp(0.4, 1.0);
    final horizontalPadding = (screenWidth * (1 - widthFactor)) / 2;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
        statusBarBrightness: dark ? Brightness.dark : Brightness.light,
        systemNavigationBarContrastEnforced: false,
      ),
      child: Scaffold(
        extendBody: true,
        body: AnimatedSwitcher(
          duration: Duration(milliseconds: settings.animations ? 350 : 0),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            final tween = Tween<Offset>(begin: _slideBegin, end: Offset.zero).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            );
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(position: tween, child: child),
            );
          },
          child: KeyedSubtree(
            key: ValueKey(_currentTab),
            child: _screenFor(_currentTab),
          ),
        ),
        bottomNavigationBar: Padding(
          padding: EdgeInsets.fromLTRB(
              horizontalPadding, 0, horizontalPadding, settings.menuBottomPadding),
          child: CustomCrystalNavBar(
            currentIndex: selectedIndex,
            onTap: (i) => _onTabSelected(ids, i),
            icons: ids.map((id) => kTabs[id]!.icon).toList(),
            labels: ids.map((id) => kTabs[id]!.label).toList(),
            selectedColor: settings.menuColor,
            unselectedColor: settings.menuColor.withOpacity(0.55),
            backgroundColor: settings.menuColor.withOpacity(settings.menuOpacity),
            indicatorColor: settings.menuColor.withOpacity(0.25),
            borderRadius: settings.menuRadius,
            blurRadius: settings.menuBlur,
            height: settings.navHeight,
            iconSize: settings.navIconSize,
            showLabels: settings.showNavLabels,
          ),
        ),
      ),
    );
  }
}

// ── نوار ناوبری کریستالی با BackdropFilter ─────────────────────────────────
class CustomCrystalNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<IconData> icons;
  final List<String> labels;
  final Color selectedColor;
  final Color unselectedColor;
  final Color backgroundColor;
  final double borderRadius;
  final Color indicatorColor;
  final double blurRadius;
  final double height;
  final double iconSize;
  final bool showLabels;

  const CustomCrystalNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.icons,
    required this.labels,
    required this.selectedColor,
    required this.unselectedColor,
    required this.backgroundColor,
    this.borderRadius = 32,
    required this.indicatorColor,
    this.blurRadius = 20,
    this.height = 72,
    this.iconSize = 24,
    this.showLabels = true,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: blurRadius, sigmaY: blurRadius),
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(icons.length, (index) {
              final isSelected = index == currentIndex;
              return GestureDetector(
                onTap: () => onTap(index),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  padding: EdgeInsets.symmetric(
                      horizontal: showLabels ? 14 : 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? indicatorColor : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        icons[index],
                        color: isSelected ? selectedColor : unselectedColor,
                        size: iconSize,
                      ),
                      if (showLabels && isSelected) ...[
                        const SizedBox(height: 2),
                        Text(
                          labels[index],
                          style: TextStyle(
                            color: selectedColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Vazir',
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ۱۰) ویجت‌های مشترک
// ═══════════════════════════════════════════════════════════════════════════

Color surfaceColor(BuildContext context) {
  final s = context.watch<SettingsProvider>();
  final dark = s.isDarkMode(MediaQuery.platformBrightnessOf(context));
  return dark ? const Color(0xFF141A2E) : Colors.white;
}

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final void Function()? onTap;

  const GlassCard({super.key, required this.child, this.margin, this.padding, this.onTap});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsProvider>();
    final dark = s.isDarkMode(MediaQuery.platformBrightnessOf(context));
    final base = surfaceColor(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: margin ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: padding ?? const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: s.glassCards ? base.withOpacity(dark ? 0.85 : 0.92) : base,
          borderRadius: BorderRadius.circular(s.cardRadius),
          border: Border.all(
              color: dark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.05)),
          boxShadow: s.cardElevation > 0
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(dark ? 0.25 : 0.06),
                    blurRadius: s.cardElevation * 4,
                    offset: Offset(0, s.cardElevation),
                  ),
                ]
              : [],
        ),
        child: child,
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget? trailing;
  const SectionHeader({super.key, required this.title, required this.icon, this.trailing});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsProvider>();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: s.accent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: s.accent),
          ),
          const SizedBox(width: 8),
          Expanded(
              child: Text(title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class ChoiceChipsRow extends StatelessWidget {
  final List<String> options;
  final int selected;
  final ValueChanged<int> onSelected;
  const ChoiceChipsRow(
      {super.key, required this.options, required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsProvider>();
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: options.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final sel = i == selected;
          return GestureDetector(
            onTap: () => onSelected(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: sel ? s.accent : surfaceColor(context),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: sel ? s.accent : Colors.grey.withOpacity(0.25)),
              ),
              child: Text(
                options[i],
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                  color: sel ? Colors.white : null,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

Widget changeBadge(BuildContext context, MarketItem item) {
  final s = context.watch<SettingsProvider>();
  final p = item.changePercent;
  final v = item.changeValue;
  final up = (p ?? v ?? 0) >= 0;
  final color = up ? s.positive : s.negative;
  final parts = <String>[];
  if (s.showPercent && p != null) parts.add('${formatNumber(p, fa: s.faDigits)}٪');
  if (s.showChangeValue && v != null) parts.add(formatNumber(v, fa: s.faDigits));
  if (parts.isEmpty) return const SizedBox.shrink();
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
        color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(up ? Icons.arrow_drop_up_rounded : Icons.arrow_drop_down_rounded,
            color: color, size: 18),
        Text(
          parts.join(' | '),
          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
        ),
      ],
    ),
  );
}

// ── اسپارک‌لاین سبک ─────────────────────────────────────────────────────────
class Sparkline extends StatelessWidget {
  final List<double> data;
  final Color color;
  final double width;
  final double height;
  const Sparkline(
      {super.key, required this.data, required this.color, this.width = 64, this.height = 28});

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: Size(width, height),
        painter: _SparkPainter(data, color),
      );
}

class _SparkPainter extends CustomPainter {
  final List<double> data;
  final Color color;
  _SparkPainter(this.data, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;
    final mn = data.reduce(math.min);
    final mx = data.reduce(math.max);
    final range = (mx - mn) == 0 ? 1.0 : (mx - mn);
    final path = Path();
    for (int i = 0; i < data.length; i++) {
      final x = i / (data.length - 1) * size.width;
      final y = size.height - ((data[i] - mn) / range) * (size.height - 4) - 2;
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = color);
    final lastX = size.width;
    final lastY = size.height - ((data.last - mn) / range) * (size.height - 4) - 2;
    canvas.drawCircle(Offset(lastX, lastY), 2.2, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _SparkPainter old) => old.data != data;
}

// ── ردیف قیمت ───────────────────────────────────────────────────────────────
class PriceTile extends StatelessWidget {
  final MarketItem item;
  const PriceTile({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsProvider>();
    final up = (item.changePercent ?? item.changeValue ?? 0) >= 0;
    final tint = item.changePercent == null && item.changeValue == null
        ? Colors.grey
        : (up ? s.positive : s.negative);
    final isCrypto = item.category == 'crypto_market';
    final isFav = s.isFavorite(item.key);

    return GlassCard(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: s.compact ? 8 : 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: tint.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              up ? Icons.trending_up_rounded : Icons.trending_down_rounded,
              color: tint,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                const SizedBox(height: 2),
                Row(children: [
                  if (isCrypto && item.priceUsd != null) ...[
                    Text('${nf(context, item.priceUsd)} دلار',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                    const SizedBox(width: 6),
                  ],
                  if (s.showTime && item.time != null && item.time!.isNotEmpty)
                    Text(localizeDigits(context, item.time!),
                        style: TextStyle(fontSize: 10.5, color: Colors.grey.shade400)),
                ]),
              ],
            ),
          ),
          if (s.showSparkline && !s.compact && item.mainValue != null) ...[
            Sparkline(
                data: genHistory(item.name, item.mainValue!),
                color: tint,
                width: 56,
                height: 26),
            const SizedBox(width: 8),
          ],
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                isCrypto
                    ? priceText(context, item.priceRial)
                    : (item.category == 'forex_pairs'
                        ? nf(context, item.rate)
                        : priceText(context, item.price)),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 4),
              changeBadge(context, item),
            ],
          ),
          SizedBox(
            width: 34,
            child: IconButton(
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              iconSize: 19,
              icon: Icon(
                isFav ? Icons.star_rounded : Icons.star_outline_rounded,
                color: isFav ? Colors.amber : Colors.grey.shade400,
              ),
              onPressed: () => s.toggleFavorite(item.key),
            ),
          ),
          SizedBox(
            width: 34,
            child: IconButton(
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              iconSize: 18,
              icon: Icon(
                s.hasAlert(item.key)
                    ? Icons.notifications_active_rounded
                    : Icons.notifications_none_rounded,
                color: s.hasAlert(item.key) ? s.accent : Colors.grey.shade400,
              ),
              onPressed: () => showAlertEditor(context, item),
            ),
          ),
        ],
      ),
    );
  }
}

class OfficeTile extends StatelessWidget {
  final OfficeItem office;
  const OfficeTile({super.key, required this.office});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsProvider>();
    return GlassCard(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: s.compact ? 8 : 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: s.accent.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.storefront_rounded, color: s.accent, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
              child: Text(office.name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5))),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('خرید: ${office.buy == null ? '—' : formatNumber(office.buy, fa: s.faDigits)}',
                style: TextStyle(fontSize: 12, color: s.positive, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text('فروش: ${office.sell == null ? '—' : formatNumber(office.sell, fa: s.faDigits)}',
                style: TextStyle(fontSize: 12, color: s.negative, fontWeight: FontWeight.bold)),
          ]),
        ],
      ),
    );
  }
}

class NewsTile extends StatelessWidget {
  final NewsItem news;
  const NewsTile({super.key, required this.news});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsProvider>();
    return GlassCard(
      onTap: () => openUrl(news.url),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: s.accent.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.article_rounded, color: s.accent, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(news.title,
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text('برای مشاهده خبر لمس کنید',
                    style: TextStyle(fontSize: 10.5, color: Colors.grey.shade400)),
              ],
            ),
          ),
          Icon(Icons.chevron_left_rounded, color: Colors.grey.shade400),
        ],
      ),
    );
  }
}

// ── افکت بارگذاری ───────────────────────────────────────────────────────────
class LoadingShimmer extends StatelessWidget {
  const LoadingShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = context.watch<SettingsProvider>().isDarkMode(MediaQuery.platformBrightnessOf(context));
    return Shimmer.fromColors(
      baseColor: dark ? const Color(0xFF1A2138) : Colors.grey.shade300,
      highlightColor: dark ? const Color(0xFF242D4A) : Colors.grey.shade100,
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: 8,
        itemBuilder: (_, __) => Container(
          height: 68,
          margin: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(20)),
        ),
      ),
    );
  }
}

Widget emptyState(String message) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inbox_rounded, size: 52, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(message, style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
        ],
      ),
    ),
  );
}

// ── دیالوگ تنظیم هشدار قیمت ─────────────────────────────────────────────────
Future<void> showAlertEditor(BuildContext context, MarketItem item) async {
  final s = context.read<SettingsProvider>();
  final market = context.read<MarketProvider>();
  final existing = s.alertFor(item.key);
  final upperCtrl = TextEditingController(
      text: existing?['above'] != null ? formatNumber(existing['above'], fa: false) : '');
  final lowerCtrl = TextEditingController(
      text: existing?['below'] != null ? formatNumber(existing['below'], fa: false) : '');

  await showDialog(
    context: context,
    builder: (ctx) => Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('هشدار قیمت «${item.name}»', style: const TextStyle(fontSize: 15)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('قیمت فعلی: ${formatNumber(item.mainValue, fa: true)} ریال',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            const SizedBox(height: 14),
            TextField(
              controller: upperCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'هشدار در صورت رسیدن به (ریال)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: lowerCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'هشدار در صورت کاهش به (ریال)', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          if (existing != null)
            TextButton(
              child: const Text('حذف هشدار', style: TextStyle(color: Colors.red)),
              onPressed: () {
                s.removeAlert(item.key);
                Navigator.pop(ctx);
              },
            ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('انصراف')),
          FilledButton(
            child: const Text('ذخیره'),
            onPressed: () {
              final above = parseUserNumber(upperCtrl.text);
              final below = parseUserNumber(lowerCtrl.text);
              s.saveAlert(item.key, item.name, above, below);
              market.load; // no-op reference
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('هشدار قیمت ذخیره شد ✅')));
            },
          ),
        ],
      ),
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════════════
// ۱۱) صفحه خانه (داشبورد)
// ═══════════════════════════════════════════════════════════════════════════

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsProvider>();
    final market = context.watch<MarketProvider>();
    final dark = s.isDarkMode(MediaQuery.platformBrightnessOf(context));
    final tickers = market.data.summary.isNotEmpty
        ? market.data.summary
        : market.allItems.take(8).toList();

    return RefreshIndicator(
      onRefresh: () => market.load(),
      child: ListView(
        padding: const EdgeInsets.only(top: 12, bottom: 140),
        children: [
          // ── هدر ──
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(s.cardRadius),
              gradient: s.gradientHeader
                  ? LinearGradient(
                      colors: [s.accent, Color.lerp(s.accent, Colors.black, 0.35)!],
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft)
                  : null,
              color: s.gradientHeader ? null : s.accent,
              boxShadow: [
                BoxShadow(
                    color: s.accent.withOpacity(0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 10))
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18), shape: BoxShape.circle),
                      child: const Icon(Icons.show_chart_rounded, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('نبض بازار',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold)),
                          SizedBox(height: 2),
                          Text('شبکه اطلاع‌رسانی طلا، سکه و ارز',
                              style: TextStyle(color: Colors.white70, fontSize: 11)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.search_rounded, color: Colors.white),
                      onPressed: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const SearchScreen())),
                    ),
                    IconButton(
                      icon: Icon(market.loading
                          ? Icons.hourglass_top_rounded
                          : Icons.refresh_rounded, color: Colors.white),
                      onPressed: market.loading ? null : () => market.load(),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _headerChip(context, Icons.calendar_today_rounded,
                        jalaliDateStr(DateTime.now())),
                    const SizedBox(width: 6),
                    _headerChip(
                        context,
                        market.online ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                        market.online ? 'آنلاین' : 'آفلاین'),
                    const SizedBox(width: 6),
                    if (market.lastUpdate != null)
                      _headerChip(context, Icons.schedule_rounded,
                          'به‌روزرسانی: ${timeStr(market.lastUpdate!)}'),
                  ],
                ),
              ],
            ),
          ),

          if (market.error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: Row(children: [
                Icon(Icons.info_outline_rounded, size: 15, color: Colors.orange.shade700),
                const SizedBox(width: 6),
                Expanded(
                    child: Text(market.error!,
                        style: TextStyle(fontSize: 11, color: Colors.orange.shade700))),
              ]),
            ),

          // ── نوار متحرک شاخص‌ها ──
          if (market.loading && tickers.isEmpty)
            const Padding(
                padding: EdgeInsets.symmetric(vertical: 16), child: LoadingShimmer())
          else ...[
            SectionHeader(title: 'شاخص‌یاب بازار', icon: Icons.speed_rounded),
            SizedBox(
              height: 116,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: tickers.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final t = tickers[i];
                  final up = (t.changePercent ?? 0) >= 0;
                  return Container(
                    width: 148,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: surfaceColor(context),
                      borderRadius: BorderRadius.circular(s.cardRadius - 6),
                      border: Border.all(
                          color: dark
                              ? Colors.white.withOpacity(0.06)
                              : Colors.black.withOpacity(0.05)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        const Spacer(),
                        Text(
                          t.category == 'crypto_market' || t.category == 'summary_tickers' && (t.price ?? 0) < 1000000
                              ? formatNumber(t.price, fa: s.faDigits)
                              : priceText(context, t.price),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        changeBadge(context, t),
                      ],
                    ),
                  );
                },
              ),
            ),

            // ── برترین‌ها ──
            if (market.topMovers.length > 4) ...[
              SectionHeader(title: 'برترین تغییرات امروز', icon: Icons.local_fire_department_rounded),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                        child: _moverColumn(context, 'بیشترین رشد 📈',
                            market.topMovers.take(4).toList(), s.positive)),
                    const SizedBox(width: 8),
                    Expanded(
                        child: _moverColumn(
                            context,
                            'بیشترین افت 📉',
                            market.topMovers.reversed.take(4).toList().reversed.toList(),
                            s.negative)),
                  ],
                ),
              ),
            ],

            // ── علاقه‌مندی‌ها ──
            if (s.favorites.isNotEmpty) ...[
              SectionHeader(title: 'علاقه‌مندی‌های شما', icon: Icons.star_rounded),
              ...market.allItems.where((i) => s.isFavorite(i.key)).take(6).map((i) => PriceTile(item: i)),
            ],

            // ── اخبار ──
            if (market.data.news.isNotEmpty) ...[
              SectionHeader(
                title: 'آخرین اخبار',
                icon: Icons.newspaper_rounded,
                trailing: GestureDetector(
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const NewsScreen())),
                  child: Text('همه', style: TextStyle(color: s.accent, fontSize: 12)),
                ),
              ),
              ...market.data.news.take(5).map((n) => NewsTile(news: n)),
            ],

            // ── تحلیل‌های تکنیکال ──
            if (market.data.analyses.isNotEmpty) ...[
              SectionHeader(title: 'تحلیل‌های تکنیکال', icon: Icons.candlestick_chart_rounded),
              SizedBox(
                height: 44,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: market.data.analyses.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final a = market.data.analyses[i];
                    return GestureDetector(
                      onTap: () => openUrl(a.url),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: surfaceColor(context),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: s.accent.withOpacity(0.35)),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.description_outlined, size: 14, color: s.accent),
                          const SizedBox(width: 6),
                          Text(a.title, style: const TextStyle(fontSize: 12)),
                        ]),
                      ),
                    );
                  },
                ),
              ),
            ],

            // ── تقویم اقتصادی ──
            if (market.data.calendar.isNotEmpty) ...[
              SectionHeader(title: 'تقویم اقتصادی', icon: Icons.event_note_rounded),
              ...market.data.calendar.take(4).map(
                    (e) => GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Directionality(
                              textDirection: TextDirection.ltr,
                              child: Text(e.name,
                                  style: const TextStyle(
                                      fontSize: 12.5, fontWeight: FontWeight.bold))),
                          const SizedBox(height: 6),
                          Row(children: [
                            _calChip(context, 'قبلی', e.previous, Colors.blueGrey),
                            const SizedBox(width: 8),
                            _calChip(context, 'پیش‌بینی', e.forecast, s.accent),
                          ]),
                        ],
                      ),
                    ),
                  ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _headerChip(BuildContext context, IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: Colors.white),
        const SizedBox(width: 5),
        Text(text, style: const TextStyle(color: Colors.white, fontSize: 10.5)),
      ]),
    );
  }

  Widget _moverColumn(BuildContext context, String title, List<MarketItem> items, Color color) {
    final s = context.watch<SettingsProvider>();
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: surfaceColor(context),
        borderRadius: BorderRadius.circular(s.cardRadius - 6),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 8),
          ...items.map(
            (i) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                Expanded(
                    child: Text(i.name,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11.5))),
                Text('${formatNumber(i.changePercent, fa: s.faDigits)}٪',
                    style: TextStyle(
                        fontSize: 11.5, fontWeight: FontWeight.bold, color: color)),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _calChip(BuildContext context, String label, String? value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
          color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text('$label: ', style: TextStyle(fontSize: 11, color: color)),
        Directionality(
            textDirection: TextDirection.ltr,
            child: Text(value ?? '-',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color))),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ۱۲) صفحه طلا و سکه
// ═══════════════════════════════════════════════════════════════════════════

class GoldScreen extends StatefulWidget {
  const GoldScreen({super.key});
  @override
  State<GoldScreen> createState() => _GoldScreenState();
}

class _GoldScreenState extends State<GoldScreen> {
  int _segment = 0;
  final _weightCtrl = TextEditingController();
  final _wageCtrl = TextEditingController(text: '20');
  final _gramPriceCtrl = TextEditingController();
  bool _prefilled = false;

  @override
  void dispose() {
    _weightCtrl.dispose();
    _wageCtrl.dispose();
    _gramPriceCtrl.dispose();
    super.dispose();
  }

  List<MarketItem> _items(MarketProvider market) {
    switch (_segment) {
      case 0: return market.data.gold.where((g) => !g.name.startsWith('صندوق')).toList();
      case 1: return market.data.gold.where((g) => g.name.startsWith('صندوق')).toList();
      case 2: return market.data.coin.where((c) => !c.name.startsWith('حباب')).toList();
      default: return market.data.coin.where((c) => c.name.startsWith('حباب')).toList();
    }
  }

  double? get _calcResult {
    final w = parseUserNumber(_weightCtrl.text);
    final wage = parseUserNumber(_wageCtrl.text);
    final price = parseUserNumber(_gramPriceCtrl.text);
    if (w == null || wage == null || price == null) return null;
    return w * price * (1 + wage / 100);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsProvider>();
    final market = context.watch<MarketProvider>();

    if (!_prefilled && market.data.gold.isNotEmpty) {
      final g18 = market.data.gold
          .firstWhere((g) => g.name.contains('18 عیار'), orElse: () => market.data.gold.first);
      if (g18.price != null) {
        _gramPriceCtrl.text = g18.price!.toStringAsFixed(0);
        _prefilled = true;
      }
    }

    final items = _items(market);

    return RefreshIndicator(
      onRefresh: () => market.load(),
      child: ListView(
        padding: const EdgeInsets.only(top: 18, bottom: 140),
        children: [
          const _ScreenTitle(title: 'بازار طلا و سکه', icon: Icons.monetization_on_rounded),
          const SizedBox(height: 10),
          ChoiceChipsRow(
            options: const ['طلا و نقره', 'صندوق‌های طلا', 'سکه', 'حباب سکه'],
            selected: _segment,
            onSelected: (i) => setState(() => _segment = i),
          ),
          const SizedBox(height: 8),

          // ── محاسبه‌گر طلا ──
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.calculate_rounded, size: 17, color: s.accent),
                  const SizedBox(width: 6),
                  const Text('محاسبه‌گر قیمت طلا',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _weightCtrl,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                          labelText: 'وزن (گرم)', isDense: true, border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _wageCtrl,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                          labelText: 'اجرت ٪', isDense: true, border: OutlineInputBorder()),
                    ),
                  ),
                ]),
                const SizedBox(height: 8),
                TextField(
                  controller: _gramPriceCtrl,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                      labelText: 'قیمت هر گرم (ریال)', isDense: true, border: OutlineInputBorder()),
                ),
                if (_calcResult != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: s.positive.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12)),
                    child: Text(
                      'قیمت نهایی با اجرت: ${priceText(context, _calcResult)}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13, color: s.positive),
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 4),
          if (market.loading && items.isEmpty)
            const LoadingShimmer()
          else if (items.isEmpty)
            emptyState('داده‌ای یافت نشد')
          else
            ...items.map((i) => PriceTile(item: i)),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ۱۳) صفحه ارز
// ═══════════════════════════════════════════════════════════════════════════

class CurrencyScreen extends StatefulWidget {
  const CurrencyScreen({super.key});
  @override
  State<CurrencyScreen> createState() => _CurrencyScreenState();
}

class _CurrencyScreenState extends State<CurrencyScreen> {
  int _segment = 0;

  @override
  Widget build(BuildContext context) {
    final market = context.watch<MarketProvider>();
    return RefreshIndicator(
      onRefresh: () => market.load(),
      child: ListView(
        padding: const EdgeInsets.only(top: 18, bottom: 140),
        children: [
          const _ScreenTitle(title: 'بازار ارز', icon: Icons.account_balance_wallet_rounded),
          const SizedBox(height: 10),
          ChoiceChipsRow(
            options: const ['ارز آزاد', 'برابری ارزها (فارکس)'],
            selected: _segment,
            onSelected: (i) => setState(() => _segment = i),
          ),
          const SizedBox(height: 8),
          if (market.loading && market.data.currency.isEmpty)
            const LoadingShimmer()
          else if (_segment == 0)
            ...market.data.currency.map((i) => PriceTile(item: i))
          else ...[
            ...market.data.forex.map((i) => PriceTile(item: i)),
            if (market.data.forex.isEmpty) emptyState('داده‌ای یافت نشد'),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ۱۴) صفحه رمزارز
// ═══════════════════════════════════════════════════════════════════════════

class CryptoScreen extends StatefulWidget {
  const CryptoScreen({super.key});
  @override
  State<CryptoScreen> createState() => _CryptoScreenState();
}

class _CryptoScreenState extends State<CryptoScreen> {
  int _segment = 0;

  @override
  Widget build(BuildContext context) {
    final market = context.watch<MarketProvider>();
    return RefreshIndicator(
      onRefresh: () => market.load(),
      child: ListView(
        padding: const EdgeInsets.only(top: 18, bottom: 140),
        children: [
          const _ScreenTitle(title: 'ارزهای دیجیتال', icon: Icons.currency_bitcoin_rounded),
          const SizedBox(height: 10),
          ChoiceChipsRow(
            options: const ['رمزارزها', 'طلای دیجیتال', 'صرافی‌های داخلی'],
            selected: _segment,
            onSelected: (i) => setState(() => _segment = i),
          ),
          const SizedBox(height: 8),
          if (market.loading && market.data.crypto.isEmpty)
            const LoadingShimmer()
          else if (_segment == 0)
            ...market.data.crypto.map((i) => PriceTile(item: i))
          else if (_segment == 1)
            ...market.data.digitalGold.map((i) => PriceTile(item: i))
          else ...[
            if (market.data.offices.isEmpty)
              emptyState('داده‌ای یافت نشد')
            else
              ...market.data.offices.map((o) => OfficeTile(office: o)),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ۱۵) صفحه نمودارها
// ═══════════════════════════════════════════════════════════════════════════

class ChartsScreen extends StatefulWidget {
  const ChartsScreen({super.key});
  @override
  State<ChartsScreen> createState() => _ChartsScreenState();
}

class _ChartsScreenState extends State<ChartsScreen> {
  int _catIndex = 0;
  String? _selectedName;

  static const _catNames = [
    'طلا', 'سکه', 'ارز', 'فارکس', 'رمزارز', 'انرژی',
    'فلزات پایه', 'کالاها', 'بورس تهران', 'شاخص‌های جهانی'
  ];

  List<MarketItem> _itemsFor(MarketProvider market, int i) {
    switch (i) {
      case 0: return market.data.gold;
      case 1: return market.data.coin;
      case 2: return market.data.currency;
      case 3: return market.data.forex;
      case 4: return market.data.crypto;
      case 5: return market.data.energy;
      case 6: return market.data.metals;
      case 7: return market.data.commodities;
      case 8: return market.data.tehran;
      default: return market.data.globalIndices;
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsProvider>();
    final market = context.watch<MarketProvider>();
    final items = _itemsFor(market, _catIndex);
    final selected = items.firstWhere(
      (i) => i.name == _selectedName,
      orElse: () => items.isNotEmpty ? items.first : MarketItem(category: '', name: ''),
    );
    final chartValue = selected.priceUsd ?? selected.mainValue;

    return RefreshIndicator(
      onRefresh: () => market.load(),
      child: ListView(
        padding: const EdgeInsets.only(top: 18, bottom: 140),
        children: [
          const _ScreenTitle(title: 'نمودارها و بازارهای جهانی', icon: Icons.insights_rounded),
          const SizedBox(height: 10),
          ChoiceChipsRow(
            options: _catNames,
            selected: _catIndex,
            onSelected: (i) => setState(() {
              _catIndex = i;
              _selectedName = null;
            }),
          ),
          const SizedBox(height: 10),

          if (items.isEmpty)
            emptyState('داده‌ای یافت نشد')
          else ...[
            // انتخاب نماد
            GlassCard(
              child: DropdownButtonFormField<String>(
                value: selected.name,
                isExpanded: true,
                decoration: const InputDecoration(
                    labelText: 'انتخاب نماد', isDense: true, border: OutlineInputBorder()),
                items: items
                    .map((i) => DropdownMenuItem(value: i.name, child: Text(i.name,
                        overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13))))
                    .toList(),
                onChanged: (v) => setState(() => _selectedName = v),
              ),
            ),

            // نمودار
            if (chartValue != null)
              GlassCard(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(selected.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold, fontSize: 14)),
                              const SizedBox(height: 4),
                              Text(
                                selected.category == 'crypto_market'
                                    ? '${nf(context, selected.priceUsd)} دلار'
                                    : (selected.category == 'forex_pairs'
                                        ? nf(context, selected.rate)
                                        : priceText(context, selected.price)),
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: s.accent),
                              ),
                            ],
                          ),
                        ),
                        changeBadge(context, selected),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 210,
                      child: LineChart(
                        LineChartData(
                          minX: 0,
                          maxX: 59,
                          minY: chartValue * 0.985,
                          maxY: chartValue * 1.015,
                          gridData: const FlGridData(show: false),
                          titlesData: const FlTitlesData(show: false),
                          borderData: FlBorderData(show: false),
                          lineTouchData: LineTouchData(
                            touchTooltip: LineTouchTooltipData(
                              getTooltipItems: (spots) => spots
                                  .map((sp) => LineTooltipItem(
                                      formatNumber(sp.y, fa: s.faDigits),
                                      const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          fontFamily: 'Vazir')))
                                  .toList(),
                            ),
                          ),
                          lineBarsData: [
                            LineChartBarData(
                              spots: [
                                for (int i = 0; i < 60; i++)
                                  FlSpot(i.toDouble(),
                                      genHistory(selected.name, chartValue)[i])
                              ],
                              isCurved: true,
                              color: s.accent,
                              barWidth: 2.5,
                              dotData: const FlDotData(show: false),
                              belowBarData: BarAreaData(
                                show: true,
                                gradient: LinearGradient(
                                  colors: [
                                    s.accent.withOpacity(0.28),
                                    s.accent.withOpacity(0.0)
                                  ],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _chartStat(context, 'کمترین', selected.low, s.negative),
                        _chartStat(context, 'بیشترین', selected.high, s.positive),
                        _chartStat(context, 'تغییر ٪', selected.changePercent, s.accent),
                      ],
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 6),
            SectionHeader(title: 'همه نمادهای ${_catNames[_catIndex]}', icon: Icons.list_rounded),
            ...items.map((i) => PriceTile(item: i)),
          ],
        ],
      ),
    );
  }

  Widget _chartStat(BuildContext context, String label, double? value, Color color) {
    return Column(children: [
      Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
      const SizedBox(height: 3),
      Text(value == null ? '—' : formatNumber(value,
          fa: context.watch<SettingsProvider>().faDigits),
          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: color)),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ۱۶) صفحه تنظیمات — شخصی‌سازی کامل
// ═══════════════════════════════════════════════════════════════════════════

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsProvider>();
    final market = context.read<MarketProvider>();

    return ListView(
      padding: const EdgeInsets.only(top: 18, bottom: 160),
      children: [
        const _ScreenTitle(title: 'تنظیمات و شخصی‌سازی', icon: Icons.settings_rounded),

        // ── حالت نمایش ──
        _SettingCard(title: 'حالت نمایش', icon: Icons.dark_mode_rounded, children: [
          ChoiceChipsRow(
            options: const ['سیستم', 'روشن', 'تاریک'],
            selected: s.themeModeIndex,
            onSelected: (i) => s.set((x) => x.themeModeIndex = i),
          ),
        ]),

        // ── رنگ‌ها ──
        _SettingCard(title: 'رنگ اصلی برنامه', icon: Icons.palette_rounded, children: [
          _colorGrid(s.palette, s.accentValue, (c) => s.set((x) => x.accentValue = c)),
          const SizedBox(height: 12),
          const Text('رنگ نوار ناوبری', style: TextStyle(fontSize: 12.5)),
          const SizedBox(height: 8),
          _colorGrid(s.palette, s.menuColorValue, (c) => s.set((x) => x.menuColorValue = c)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('رنگ رشد', style: TextStyle(fontSize: 12.5)),
              const SizedBox(height: 6),
              _colorGrid(s.palette.sublist(3, 8), s.positiveValue,
                  (c) => s.set((x) => x.positiveValue = c), size: 30),
            ])),
            const SizedBox(width: 12),
            Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('رنگ افت', style: TextStyle(fontSize: 12.5)),
              const SizedBox(height: 6),
              _colorGrid(s.palette.sublist(0, 5), s.negativeValue,
                  (c) => s.set((x) => x.negativeValue = c), size: 30),
            ])),
          ]),
        ]),

        // ── نوار ناوبری ──
        _SettingCard(title: 'نوار ناوبری بلور', icon: Icons.blur_on_rounded, children: [
          _sliderRow('عرض نوار (٪)', s.menuWidthPercent, 40, 100, 60,
              (v) => s.set((x) => x.menuWidthPercent = v)),
          _sliderRow('فاصله از پایین', s.menuBottomPadding, 0, 48, 48,
              (v) => s.set((x) => x.menuBottomPadding = v)),
          _sliderRow('شدت تاری (بلور)', s.menuBlur, 0, 40, 40,
              (v) => s.set((x) => x.menuBlur = v)),
          _sliderRow('شفافیت پس‌زمینه', s.menuOpacity, 0.05, 0.5, 45,
              (v) => s.set((x) => x.menuOpacity = v)),
          _sliderRow('گردی گوشه‌ها', s.menuRadius, 12, 40, 28,
              (v) => s.set((x) => x.menuRadius = v)),
          _sliderRow('ارتفاع نوار', s.navHeight, 56, 92, 36,
              (v) => s.set((x) => x.navHeight = v)),
          _sliderRow('اندازه آیکون‌ها', s.navIconSize, 18, 32, 14,
              (v) => s.set((x) => x.navIconSize = v)),
          SwitchListTile(
            dense: true,
            title: const Text('نمایش برچسب تب فعال'),
            value: s.showNavLabels,
            onChanged: (v) => s.set((x) => x.showNavLabels = v),
          ),
        ]),

        // ── کارت‌ها و ظاهر ──
        _SettingCard(title: 'کارت‌ها و ظاهر', icon: Icons.dashboard_customize_rounded, children: [
          _sliderRow('گردی کارت‌ها', s.cardRadius, 8, 36, 28,
              (v) => s.set((x) => x.cardRadius = v)),
          _sliderRow('ارتفاع سایه', s.cardElevation, 0, 8, 8,
              (v) => s.set((x) => x.cardElevation = v)),
          _sliderRow('اندازه فونت', s.fontScale, 0.8, 1.3, 10,
              (v) => s.set((x) => x.fontScale = v)),
          SwitchListTile(dense: true, title: const Text('کارت‌های شیشه‌ای'),
              value: s.glassCards, onChanged: (v) => s.set((x) => x.glassCards = v)),
          SwitchListTile(dense: true, title: const Text('هدر گرادیانی'),
              value: s.gradientHeader, onChanged: (v) => s.set((x) => x.gradientHeader = v)),
          SwitchListTile(dense: true, title: const Text('انیمیشن تغییر تب'),
              value: s.animations, onChanged: (v) => s.set((x) => x.animations = v)),
          SwitchListTile(dense: true, title: const Text('نمایش فشرده لیست‌ها'),
              value: s.compact, onChanged: (v) => s.set((x) => x.compact = v)),
          SwitchListTile(dense: true, title: const Text('نمودار کوچک (اسپارک‌لاین)'),
              value: s.showSparkline, onChanged: (v) => s.set((x) => x.showSparkline = v)),
        ]),

        // ── اعداد و قیمت‌ها ──
        _SettingCard(title: 'اعداد و قیمت‌ها', icon: Icons.numbers_rounded, children: [
          SwitchListTile(dense: true, title: const Text('نمایش اعداد فارسی (۱۲۳)'),
              value: s.faDigits, onChanged: (v) => s.set((x) => x.faDigits = v)),
          SwitchListTile(dense: true, title: const Text('نمایش درصد تغییر'),
              value: s.showPercent, onChanged: (v) => s.set((x) => x.showPercent = v)),
          SwitchListTile(dense: true, title: const Text('نمایش مقدار تغییر'),
              value: s.showChangeValue, onChanged: (v) => s.set((x) => x.showChangeValue = v)),
          SwitchListTile(dense: true, title: const Text('نمایش زمان قیمت'),
              value: s.showTime, onChanged: (v) => s.set((x) => x.showTime = v)),
          const SizedBox(height: 8),
          const Text('واحد نمایش قیمت‌ها', style: TextStyle(fontSize: 12.5)),
          const SizedBox(height: 8),
          ChoiceChipsRow(
            options: const ['ریال', 'تومان'],
            selected: s.priceUnitIndex,
            onSelected: (i) => s.set((x) => x.priceUnitIndex = i),
          ),
        ]),

        // ── داده‌ها ──
        _SettingCard(title: 'داده‌ها و به‌روزرسانی', icon: Icons.cloud_sync_rounded, children: [
          SwitchListTile(dense: true, title: const Text('دریافت آنلاین از سایت TGJU'),
              value: s.onlineMode, onChanged: (v) => s.set((x) => x.onlineMode = v)),
          const SizedBox(height: 8),
          const Text('فاصله به‌روزرسانی خودکار', style: TextStyle(fontSize: 12.5)),
          const SizedBox(height: 8),
          ChoiceChipsRow(
            options: const ['۱ دقیقه', '۵ دقیقه', '۱۵ دقیقه', '۱ ساعت'],
            selected: const [1, 5, 15, 60].indexOf(s.refreshMinutes),
            onSelected: (i) =>
                s.set((x) => x.refreshMinutes = const [1, 5, 15, 60][i]),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () => market.load(),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('به‌روزرسانی اکنون'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => market.load(forceDemo: true),
                icon: const Icon(Icons.offline_bolt_rounded, size: 18),
                label: const Text('داده نمونه'),
              ),
            ),
          ]),
        ]),

        // ── مدیریت تب‌ها ──
        _SettingCard(title: 'شخصی‌سازی تب‌ها', icon: Icons.tab_rounded, children: [
          const Text('ترتیب و نمایش تب‌ها را با کشیدن جابه‌جا کنید',
              style: TextStyle(fontSize: 11.5)),
          const SizedBox(height: 6),
          ReorderableListView(
            shrinkWrap: true,
            onReorder: s.reorderTabs,
            children: [
              for (final id in s.tabOrder)
                ListTile(
                  key: ValueKey(id),
                  dense: true,
                  leading: Icon(kTabs[id]!.icon, size: 20, color: s.accent),
                  title: Text(kTabs[id]!.label, style: const TextStyle(fontSize: 13)),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    Switch(
                      value: !s.hiddenTabs.contains(id),
                      onChanged: (id == 'home' || id == 'settings')
                          ? null
                          : (_) => s.toggleTabVisible(id),
                    ),
                    const Icon(Icons.drag_handle_rounded, size: 18),
                  ]),
                ),
            ],
          ),
          const SizedBox(height: 8),
          const Text('تب پیش‌فرض هنگام شروع', style: TextStyle(fontSize: 12.5)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: s.visibleTabs.contains(s.defaultTab) ? s.defaultTab : 'home',
            isExpanded: true,
            decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
            items: s.visibleTabs
                .map((id) => DropdownMenuItem(
                    value: id, child: Text(kTabs[id]!.label, style: const TextStyle(fontSize: 13))))
                .toList(),
            onChanged: (v) => s.set((x) => x.defaultTab = v ?? 'home'),
          ),
        ]),

        // ── علاقه‌مندی و هشدارها ──
        _SettingCard(title: 'علاقه‌مندی‌ها و هشدارها', icon: Icons.notifications_rounded, children: [
          Row(children: [
            _infoBadge(context, Icons.star_rounded, '${formatNumber(s.favorites.length)} علاقه‌مندی', Colors.amber),
            const SizedBox(width: 8),
            _infoBadge(context, Icons.notifications_active_rounded,
                '${formatNumber(s.alerts.length)} هشدار فعال', s.accent),
          ]),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => s.set((x) {
              x.favorites.clear();
              x.alerts.clear();
            }),
            icon: const Icon(Icons.delete_sweep_rounded, size: 18, color: Colors.red),
            label: const Text('پاک‌سازی همه', style: TextStyle(color: Colors.red)),
          ),
        ]),

        // ── درباره ──
        _SettingCard(title: 'درباره برنامه', icon: Icons.info_rounded, children: [
          const Text('نبض بازار — نسخه ۱٫۰',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 4),
          Text(
            'منبع داده: شبکه اطلاع‌رسانی طلا و ارز (tgju.org) — منطق استخراج مطابق اسکریپت اختصاصی. '
            'این برنامه صرفاً نمایش‌دهنده قیمت‌هاست و توصیه سرمایه‌گذاری نیست.',
            style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500, height: 1.8),
          ),
        ]),
      ],
    );
  }

  Widget _infoBadge(BuildContext context, IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
          color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 6),
        Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
      ]),
    );
  }

  Widget _colorGrid(List<int> colors, int selected, ValueChanged<int> onPick, {double size = 38}) {
    return Wrap(
      spacing: 9,
      runSpacing: 9,
      children: colors.map((c) {
        final sel = c == selected;
        return GestureDetector(
          onTap: () => onPick(c),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: Color(c),
              shape: BoxShape.circle,
              border: Border.all(color: sel ? Colors.white : Colors.transparent, width: 3),
              boxShadow: sel
                  ? [BoxShadow(color: Color(c).withOpacity(0.6), blurRadius: 10)]
                  : [],
            ),
            child: sel ? const Icon(Icons.check_rounded, color: Colors.white, size: 16) : null,
          ),
        );
      }).toList(),
    );
  }

  Widget _sliderRow(String title, double value, double min, double max, int divisions,
      ValueChanged<double> onChanged) {
    return Column(children: [
      Row(children: [
        Expanded(child: Text(title, style: const TextStyle(fontSize: 12.5))),
        Text(formatNumber(value),
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      ]),
      Slider(value: value, min: min, max: max, divisions: divisions, onChanged: onChanged),
    ]);
  }
}

class _SettingCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  const _SettingCard({required this.title, required this.icon, required this.children});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsProvider>();
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 17, color: s.accent),
            const SizedBox(width: 7),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
          ]),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ۱۷) صفحه جستجو و اخبار
// ═══════════════════════════════════════════════════════════════════════════

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _ctrl = TextEditingController();
  String _q = '';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final market = context.watch<MarketProvider>();
    final s = context.watch<SettingsProvider>();
    final q = _q.trim();
    final items = q.isEmpty
        ? <MarketItem>[]
        : market.allItems.where((i) => i.name.contains(q)).toList();
    final news = q.isEmpty
        ? <NewsItem>[]
        : market.data.news.where((n) => n.title.contains(q)).toList();

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _ctrl,
          autofocus: true,
          onChanged: (v) => setState(() => _q = v),
          decoration: const InputDecoration(
              hintText: 'جستجوی نماد، ارز، رمزارز یا خبر...',
              border: InputBorder.none,
              hintStyle: TextStyle(fontSize: 13)),
        ),
        actions: [
          if (_ctrl.text.isNotEmpty)
            IconButton(
                icon: const Icon(Icons.clear_rounded),
                onPressed: () {
                  _ctrl.clear();
                  setState(() => _q = '');
                }),
        ],
      ),
      body: q.isEmpty
          ? emptyState('عبارتی برای جستجو وارد کنید')
          : ListView(
              padding: const EdgeInsets.only(bottom: 40),
              children: [
                if (items.isNotEmpty) ...[
                  SectionHeader(
                      title: '${formatNumber(items.length, fa: s.faDigits)} نماد یافت شد',
                      icon: Icons.search_rounded),
                  ...items.map((i) => PriceTile(item: i)),
                ],
                if (news.isNotEmpty) ...[
                  SectionHeader(
                      title: '${formatNumber(news.length, fa: s.faDigits)} خبر یافت شد',
                      icon: Icons.newspaper_rounded),
                  ...news.map((n) => NewsTile(news: n)),
                ],
                if (items.isEmpty && news.isEmpty) emptyState('نتیجه‌ای یافت نشد'),
              ],
            ),
    );
  }
}

class NewsScreen extends StatelessWidget {
  const NewsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final market = context.watch<MarketProvider>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('آخرین اخبار', style: TextStyle(fontSize: 15)),
        centerTitle: true,
      ),
      body: market.data.news.isEmpty
          ? emptyState('خبری یافت نشد')
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: market.data.news.map((n) => NewsTile(news: n)).toList(),
            ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ۱۸) عنوان صفحات
// ═══════════════════════════════════════════════════════════════════════════

class _ScreenTitle extends StatelessWidget {
  final String title;
  final IconData icon;
  const _ScreenTitle({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsProvider>();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            gradient: LinearGradient(
                colors: [s.accent, Color.lerp(s.accent, Colors.black, 0.3)!]),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                  color: s.accent.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 5))
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 10),
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ]),
    );
  }
}