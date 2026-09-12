/// TGJU Full Scraper — Dart/Flutter Version
library tgju_scraper;

import 'dart:async';
import 'dart:convert';

import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

// ============================================================
// Constants
// ============================================================

const String kTgjuBaseUrl = 'https://www.tgju.org/';

// ============================================================
// Helpers
// ============================================================

const Map<String, String> _persianDigitMap = {
  '۰': '0', '۱': '1', '۲': '2', '۳': '3', '۴': '4',
  '۵': '5', '۶': '6', '۷': '7', '۸': '8', '۹': '9',
  '٠': '0', '١': '1', '٢': '2', '٣': '3', '٤': '4',
  '٥': '5', '٦': '6', '٧': '7', '٨': '8', '٩': '9',
};

String faToEnDigits(String? text) {
  if (text == null || text.isEmpty) return '';
  final buffer = StringBuffer();
  for (int i = 0; i < text.length; i++) {
    final ch = text[i];
    buffer.write(_persianDigitMap[ch] ?? ch);
  }
  return buffer.toString();
}

String cleanText(Object? value) {
  if (value == null) return '';
  return value.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
}

double? toNumber(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  String s = faToEnDigits(value.toString());
  s = s.replaceAll(',', '').replaceAll('٪', '').replaceAll('%', '').trim();
  s = s.replaceAll(RegExp(r'[^\d.\-]'), '');
  if (s.isEmpty || s == '-' || s == '.' || s == '-.') return null;
  return double.tryParse(s);
}

/// بازگرداندن (changePct, changeValue)
(double?, double?) parsePctAndValue(String? text) {
  if (text == null || text.isEmpty) return (null, null);
  final textEn = faToEnDigits(text);
  final m = RegExp(r'\(([\d.\-]+)%\)').firstMatch(textEn);
  if (m != null) {
    final pct = double.tryParse(m.group(1)!);
    final val = toNumber(textEn.replaceAll(m.group(0)!, ''));
    return (pct, val);
  }
  return (null, toNumber(textEn));
}

double? computeChangePct(double? price, double? changeValue, String? direction) {
  if (price == null || changeValue == null || direction == null) return null;
  final base = direction == 'high' ? price - changeValue : price + changeValue;
  if (base <= 0) return null;
  return double.parse((changeValue / base * 100).toStringAsFixed(4));
}

String? getDirection(String? klass) {
  if (klass == null || klass.isEmpty) return null;
  if (klass.contains('high')) return 'high';
  if (klass.contains('low')) return 'low';
  return null;
}

/// معادل `extractText` پایتون: استخراج همه‌ی متن‌های داخلی
String extractText(dom.Element el) {
  final parts = <String>[];
  void walk(dom.Node n) {
    for (final c in n.nodes) {
      if (c is dom.Text) {
        final t = c.text;
        if (t.isNotEmpty) parts.add(t);
      } else if (c is dom.Element) {
        walk(c);
      }
    }
  }
  walk(el);
  return cleanText(parts.join(' '));
}

// ============================================================
// data-title parser
// ============================================================

class DataTitleResult {
  final List<Map<String, dynamic>> history;
  final double? firstRate;
  const DataTitleResult(this.history, this.firstRate);
}

DataTitleResult parseDataTitle(String? html) {
  final history = <Map<String, dynamic>>[];
  if (html == null || html.isEmpty) return const DataTitleResult([], null);

  final re = RegExp(
    r"<span class='tooltip-row-txt'>([^<]*)</span>\s*"
    r"<span class='tooltip-row-change'><span class='type\s*(\w*)'>"
    r"\(([\d.\-]+)%\)\s*([^<]*)</span>",
  );
  for (final m in re.allMatches(html)) {
    final txt = m.group(1)!;
    final direction = m.group(2)!;
    final pct = m.group(3)!;
    final val = m.group(4)!;
    final parts = faToEnDigits(txt).split(' در ');
    history.add({
      'price': parts.isNotEmpty ? toNumber(parts[0].trim()) : null,
      'time': parts.length > 1 ? parts[1].trim() : '',
      'direction': direction.isEmpty ? null : direction,
      'change_pct': double.tryParse(pct),
      'change_value': toNumber(val),
    });
  }

  double? firstRate;
  final fm = RegExp(r'اولین نرخ امروز:\s*([\d,.\-]+)').firstMatch(html);
  if (fm != null) firstRate = toNumber(fm.group(1));

  return DataTitleResult(history, firstRate);
}

// ============================================================
// Row parser
// ============================================================

String? _extractFlag(dom.Element tr) {
  final flagEl = tr.querySelector('span.mini-flag');
  if (flagEl == null) return null;
  final m = RegExp(r'flag-([\w\-]+)')
      .firstMatch(flagEl.attributes['class'] ?? '');
  return m?.group(1);
}

Map<String, dynamic>? _parseOneRow(dom.Element tr) {
  final rowKey = (tr.attributes['data-market-row'] ?? '').trim();
  final nameslug = (tr.attributes['data-market-nameslug'] ?? '').trim();
  final slug = (rowKey.isNotEmpty ? rowKey : nameslug)
      .replaceAll('disabled_', '');
  if (slug.isEmpty) return null;

  final title = cleanText(
    tr.children
        .where((c) => c.localName == 'th')
        .map((th) => extractText(th))
        .join(' '),
  );
  final flag = _extractFlag(tr);

  double? priceIrr, priceUsd, priceNum;
  String? priceRaw;
  String? changeRaw;
  String? direction;
  double? low, high;
  String? timeStr;

  final isCrypto = tr.querySelector('td.market-price-irr') != null;
  final isExchange = tr.querySelectorAll('td').any((td) =>
      (td.attributes['class'] ?? '').contains('market-currency-'));

  if (isCrypto) {
    final irrEl = tr.querySelector('td.market-price-irr');
    final usdEl = tr.querySelector('td.market-price');
    if (irrEl != null) priceIrr = toNumber(extractText(irrEl));
    if (usdEl != null) priceUsd = toNumber(extractText(usdEl));
    if (usdEl != null) {
      priceRaw = extractText(usdEl);
    } else if (irrEl != null) {
      priceRaw = extractText(irrEl);
    }

    final changeTd = tr.querySelector('td.market-percentage');
    if (changeTd != null) {
      final inner = changeTd.querySelectorAll('div, span');
      if (inner.isNotEmpty) {
        changeRaw = extractText(inner.first);
        direction = getDirection(inner.first.attributes['class'] ?? '');
      }
    }

    for (final entry in [
      ('market-low', 'low'),
      ('market-high', 'high'),
      ('market-time', 'time'),
    ]) {
      final el = tr.querySelector('td.${entry.$1}');
      if (el == null) continue;
      final txt = extractText(el);
      if (entry.$2 == 'low') {
        low = toNumber(txt);
      } else if (entry.$2 == 'high') {
        high = toNumber(txt);
      } else {
        timeStr = txt;
      }
    }
  } else if (isExchange) {
    dom.Element? targetTd;
    for (final td in tr.querySelectorAll('td[data-market-p]')) {
      if (td.attributes['data-market-p'] == slug) {
        targetTd = td;
        break;
      }
    }
    if (targetTd == null) {
      for (final td in tr.querySelectorAll('td')) {
        final cls = td.attributes['class'] ?? '';
        if (!cls.contains('market-currency-')) continue;
        final inner = td.querySelectorAll('div, span');
        if (inner.isNotEmpty && extractText(inner.first).isNotEmpty) {
          targetTd = td;
          break;
        }
      }
    }
    if (targetTd != null) {
      final inner = targetTd.querySelectorAll('div, span');
      if (inner.isNotEmpty) {
        priceRaw = extractText(inner.first);
        direction = getDirection(inner.first.attributes['class'] ?? '');
      } else {
        priceRaw = extractText(targetTd);
      }
    }
  } else {
    // ---------- CLASSIC ----------
    for (final td in tr.querySelectorAll('td.nf')) {
      final span = td.querySelector('span');
      if (span != null) {
        if (changeRaw == null) {
          changeRaw = extractText(span);
          direction = getDirection(span.attributes['class'] ?? '');
        }
      } else {
        final txt = extractText(td);
        if (priceRaw == null && txt.isNotEmpty) priceRaw = txt;
      }
    }

    if (changeRaw == null) {
      for (final td in tr.querySelectorAll('td')) {
        if ((td.attributes['class'] ?? '').isNotEmpty) continue;
        final span = td.querySelector('span');
        if (span != null) {
          changeRaw = extractText(span);
          direction = getDirection(span.attributes['class'] ?? '');
          break;
        }
      }
    }

    if (changeRaw == null) {
      for (final td in tr.querySelectorAll('td.market-percentage')) {
        final div = td.querySelector('div');
        if (div != null) {
          changeRaw = extractText(div);
          direction = getDirection(div.attributes['class'] ?? '');
          break;
        }
      }
    }

    if (priceRaw == null) {
      for (final td in tr.querySelectorAll('td.market-price')) {
        final txt = extractText(td);
        if (txt.isNotEmpty) {
          priceRaw = txt;
          break;
        }
      }
    }

    if (priceRaw == null) {
      final dp = (tr.attributes['data-price'] ?? '').trim();
      if (dp.isNotEmpty) priceRaw = dp;
    }

    for (final cls in ['market-low', 'market-high', 'market-time']) {
      final el = tr.querySelector('td.$cls');
      if (el == null) continue;
      final txt = extractText(el);
      if (cls == 'market-low') {
        low = toNumber(txt);
      } else if (cls == 'market-high') {
        high = toNumber(txt);
      } else {
        timeStr = txt;
      }
    }
  }

  final pv = parsePctAndValue(changeRaw);
  double? changePct = pv.$1;
  final double? changeValue = pv.$2;
  priceNum = toNumber(priceRaw);

  if (changePct == null && changeValue != null && priceNum != null) {
    changePct = computeChangePct(priceNum, changeValue, direction);
  }

  final dt = parseDataTitle(tr.attributes['data-title']);
  final history = dt.history;
  final firstRate = dt.firstRate;

  if ((timeStr == null || timeStr.isEmpty) && history.isNotEmpty) {
    final t = history.first['time'];
    if (t is String && t.isNotEmpty) timeStr = t;
  }

  return <String, dynamic>{
    'title': title,
    'slug': slug,
    'row_key': rowKey,
    'nameslug': nameslug,
    'flag': flag,
    'price': priceNum,
    'price_raw': priceRaw,
    'price_irr': priceIrr,
    'price_usd': priceUsd,
    'change': changeValue,
    'change_pct': changePct,
    'direction': direction,
    'low': low,
    'high': high,
    'time': timeStr,
    'market_coding': tr.attributes['data-market-coding'],
    'history': history,
    'first_rate_today': firstRate,
  };
}

bool _isEmpty(Object? v) {
  if (v == null) return true;
  if (v is String) return v.isEmpty;
  if (v is List) return v.isEmpty;
  if (v is Map) return v.isEmpty;
  return false;
}

Map<String, dynamic> _merge(
    Map<String, dynamic> existing, Map<String, dynamic> incoming) {
  incoming.forEach((k, v) {
    if (_isEmpty(v)) return;
    final cur = existing[k];
    if (_isEmpty(cur)) {
      existing[k] = v;
    } else if (k == 'title' &&
        v.toString().length > cur.toString().length) {
      existing[k] = v;
    }
  });
  return existing;
}

Map<String, Map<String, dynamic>> parseMarketRows(dom.Document sel) {
  final result = <String, Map<String, dynamic>>{};
  for (final tr in sel.querySelectorAll('tr[data-market-row]')) {
    final parsed = _parseOneRow(tr);
    if (parsed == null) continue;
    final slug = parsed['slug'] as String;
    if (result.containsKey(slug)) {
      result[slug] = _merge(result[slug]!, parsed);
    } else {
      result[slug] = parsed;
    }
  }
  return result;
}

// ============================================================
// Section parsers
// ============================================================

Map<String, Map<String, dynamic>> parseInfoBar(dom.Document sel) {
  final result = <String, Map<String, dynamic>>{};
  for (final li in sel.querySelectorAll('ul.info-bar > li')) {
    final liId = li.attributes['id'] ?? '';
    if (!liId.startsWith('l-')) continue;
    String slug = liId.substring(2);
    if (slug.startsWith('crypto-') && slug.endsWith('-irr')) {
      slug = slug.substring(0, slug.length - 4);
    }

    final changeText = cleanText(
      li.querySelectorAll('span.info-change').map((e) => e.text).join(' '),
    );
    final priceRaw = cleanText(
      li.querySelectorAll('span.info-price').map((e) => e.text).join(' '),
    );
    final pv = parsePctAndValue(changeText);

    result[slug] = <String, dynamic>{
      'title': cleanText(
        li.querySelectorAll('h3').map((e) => e.text).join(' '),
      ),
      'price': toNumber(priceRaw),
      'price_raw': priceRaw,
      'change': pv.$2,
      'change_pct': pv.$1,
      'direction': getDirection(li.attributes['class'] ?? ''),
    };
  }
  return result;
}

Map<String, Map<String, dynamic>> parseSummaryWidgets(dom.Document sel) {
  final result = <String, Map<String, dynamic>>{};
  for (final w in sel.querySelectorAll('.summary-widget[data-market-row]')) {
    final slug = w.attributes['data-market-row']!;
    final price =
        cleanText(w.querySelector('[data-market-name="p"]')?.text ?? '');
    final change =
        cleanText(w.querySelector('[data-market-name="d"]')?.text ?? '');
    final pv = parsePctAndValue(change);
    result[slug] = <String, dynamic>{
      'title': cleanText(w.querySelector('.summary-widget-title')?.text ?? ''),
      'url': w.querySelector('.summary-widget-title')?.attributes['href'],
      'price': toNumber(price),
      'price_raw': price,
      'change': pv.$2,
      'change_pct': pv.$1,
    };
  }
  return result;
}

Map<String, Map<String, dynamic>> parseIndexTabsSummary(dom.Document sel) {
  final result = <String, Map<String, dynamic>>{};
  for (final box in sel.querySelectorAll('.index-tabs-summery[data-index]')) {
    final slug = box.attributes['data-index']!;
    final items = <String, String>{};
    for (final it in box.querySelectorAll('.summery-item')) {
      final label =
          cleanText(it.querySelector('.summery-item-title')?.text ?? '');
      final value =
          cleanText(it.querySelector('.summery-item-num')?.text ?? '');
      if (label.isNotEmpty) items[label] = value;
    }
    result[slug] = <String, dynamic>{
      'title': cleanText(box.querySelector('.summery-title')?.text ?? ''),
      'raw_date': cleanText(
        box
            .querySelectorAll('.summery-description-line')
            .map((e) => e.text)
            .join(' '),
      ),
      'items': items,
      'price': toNumber(items['قیمت به ریال']),
      'daily_change': items['تغییر روزانه'],
      'change_3m': items['تغییر ۳ ماهه'],
      'change_6m': items['تغییر ۶ ماهه'],
      'yearly_range': items['نوسان سالیانه'],
    };
  }
  return result;
}

Map<String, Map<String, dynamic>> parseTableHeaderSummary(dom.Document sel) {
  final result = <String, Map<String, dynamic>>{};
  for (final box
      in sel.querySelectorAll('.table-header-summary-container[data-index]')) {
    final slug = box.attributes['data-index']!;

    String firstDivText(String containerSelector) {
      final c = box.querySelector(containerSelector);
      if (c == null) return '';
      final d = c.querySelector('div');
      return cleanText(d?.text ?? '');
    }

    final priceRaw = firstDivText('.table-header-summary-bottom-price');
    result[slug] = <String, dynamic>{
      'title': cleanText(box.querySelector('h2')?.text ?? ''),
      'price': toNumber(priceRaw),
      'price_raw': priceRaw,
      'daily_change': firstDivText('.table-header-summary-bottom-dt'),
      'date': firstDivText('.table-header-summary-bottom-date'),
      'time': cleanText(
        box
            .querySelectorAll('.table-header-summary-bottom-date span')
            .map((e) => e.text)
            .join(' '),
      ),
      'change_3m': firstDivText('.table-header-summary-bottom-dt1'),
      'change_6m': firstDivText('.table-header-summary-bottom-dt2'),
      'yearly_range': firstDivText('.table-header-summary-bottom-dt3'),
    };
  }
  return result;
}

List<Map<String, dynamic>> parseCryptoExchanges(dom.Document sel) {
  final rows = <Map<String, dynamic>>[];
  for (final tr in sel.querySelectorAll('.freeCurrency-table tbody tr')) {
    final tds = tr.querySelectorAll('td');
    if (tds.length < 4) continue;
    final aEl = tds[0].querySelector('a');
    final aText = aEl != null ? cleanText(aEl.text) : '';
    final name = aText.isNotEmpty ? aText : extractText(tds[0]);
    final buy = extractText(tds[1]);
    final sell = extractText(tds[2]);
    final t = extractText(tds[3]);
    rows.add(<String, dynamic>{
      'exchange': name,
      'buy': toNumber(buy),
      'buy_raw': buy,
      'sell': toNumber(sell),
      'sell_raw': sell,
      'time': t,
      'url': aEl?.attributes['href'],
    });
  }
  return rows;
}

List<Map<String, dynamic>> parseTechnicals(dom.Document sel) {
  final cards = <Map<String, dynamic>>[];
  for (final c in sel.querySelectorAll('.card-technical')) {
    final contentEl = c.querySelector('.card-technical-content');
    final content = contentEl != null ? extractText(contentEl) : '';
    cards.add(<String, dynamic>{
      'title': cleanText(c.querySelector('h2')?.text ?? ''),
      'url': c.querySelector('h2 a')?.attributes['href'],
      'analyst':
          cleanText(c.querySelector('.card-technical-user-name')?.text ?? ''),
      'market':
          cleanText(c.querySelector('.card-technical-market')?.text ?? ''),
      'time':
          cleanText(c.querySelector('.card-technical-user-date')?.text ?? ''),
      'image': c
          .querySelector('img.carousel-cell-image')
          ?.attributes['data-flickity-lazyload'],
      'content':
          content.length > 500 ? '${content.substring(0, 500)}...' : content,
    });
  }
  return cards;
}

List<Map<String, dynamic>> parseCalendar(dom.Document sel) {
  final events = <Map<String, dynamic>>[];
  for (final tr
      in sel.querySelectorAll('.dayCalendar-inner table tbody tr')) {
    final tds = tr.querySelectorAll('td');
    if (tds.length < 3) continue;
    final first = tds[0];
    final flagEl = first.querySelector('.dayCalendar-flag');
    String? flag;
    if (flagEl != null) {
      final m = RegExp(r'flag-([\w\-]+)')
          .firstMatch(flagEl.attributes['class'] ?? '');
      flag = m?.group(1);
    }
    events.add(<String, dynamic>{
      'time': cleanText(first.querySelector('.dayCalendar-time')?.text ?? ''),
      'country':
          cleanText(first.querySelector('.dayCalendar-country')?.text ?? ''),
      'flag': flag,
      'title':
          cleanText(first.querySelector('.dayCalendar-title')?.text ?? ''),
      'previous': extractText(tds[1]),
      'forecast': extractText(tds[2]),
    });
  }
  return events;
}

List<Map<String, dynamic>> parseHeaderNews(dom.Document sel) {
  String scriptText = '';
  for (final s in sel.querySelectorAll('script')) {
    final txt = s.text;
    if (txt.contains('var news_items')) {
      scriptText = txt;
      break;
    }
  }
  if (scriptText.isEmpty) return [];

  final m = RegExp(r'var news_items\s*=\s*(\[.*?\]);', dotAll: true)
      .firstMatch(scriptText);
  if (m == null) return [];

  dynamic parsed;
  try {
    parsed = jsonDecode(m.group(1)!);
  } catch (_) {
    return [];
  }
  if (parsed is! List) return [];

  return parsed.map<Map<String, dynamic>>((raw) {
    final it = raw as Map<String, dynamic>;
    return <String, dynamic>{
      'id': it['id'],
      'title': it['title'],
      'category': it['category_title'],
      'created_at': it['jalali_created_at'],
      'url': 'https://www.tgju.org/news/${it['id']}/${it['slug'] ?? ''}',
    };
  }).toList();
}

List<Map<String, String>> parseWorldMap(dom.Document sel) {
  final result = <Map<String, String>>[];
  for (final opt in sel.querySelectorAll('#world-map-select option')) {
    final value = opt.attributes['value'] ?? '';
    if (value.isEmpty || value == 'hide') continue;
    result.add(<String, String>{
      'code': value,
      'title': cleanText(opt.text),
      'flag': opt.attributes['data-flag'] ?? '',
    });
  }
  return result;
}

Map<String, String?> parseServerTime(dom.Document sel) {
  final el = sel.querySelector('#server-time');
  if (el == null) return {};
  return <String, String?>{
    'value': el.attributes['data-value'],
    'server': el.attributes['data-server'],
  };
}

// ============================================================
// Main Scraper
// ============================================================

class TgjuScraper {
  static const String baseUrl = kTgjuBaseUrl;

  final http.Client _client;
  final bool _ownsClient;
  final Map<String, String> _headers;

  TgjuScraper({http.Client? client})
      : _client = client ?? http.Client(),
        _ownsClient = client == null,
        _headers = const {
          'Accept-Language': 'fa-IR,fa;q=0.9,en;q=0.8',
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Referer': kTgjuBaseUrl,
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
              'AppleWebKit/537.36 (KHTML, like Gecko) '
              'Chrome/124.0.0.0 Safari/537.36',
        };

  Future<String> fetch([String? url]) async {
    final response = await _client
        .get(Uri.parse(url ?? baseUrl), headers: _headers)
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode} for ${url ?? baseUrl}');
    }
    return utf8.decode(response.bodyBytes);
  }

  Map<String, dynamic> parse(String html) {
    final sel = html_parser.parse(html);

    final infoBar = parseInfoBar(sel);
    final markets = parseMarketRows(sel);

    infoBar.forEach((slug, item) {
      if (markets.containsKey(slug)) {
        item.forEach((k, v) {
          if (_isEmpty(v)) return;
          final cur = markets[slug]![k];
          if (_isEmpty(cur)) {
            markets[slug]![k] = v;
          } else if (k == 'title' &&
              v.toString().length > cur.toString().length) {
            markets[slug]![k] = v;
          }
        });
      } else {
        markets[slug] = <String, dynamic>{
          ...item,
          'slug': slug,
          'row_key': null,
          'nameslug': null,
          'flag': null,
          'low': null,
          'high': null,
          'time': null,
          'market_coding': null,
          'history': <Map<String, dynamic>>[],
          'first_rate_today': null,
          'price_irr': null,
          'price_usd': null,
        };
      }
    });

    return <String, dynamic>{
      'meta': <String, dynamic>{
        'scraped_at_utc': DateTime.now().toUtc().toIso8601String(),
        'source': baseUrl,
        'server_time': parseServerTime(sel),
      },
      'markets': markets,
      'info_bar': infoBar,
      'summary_widgets': parseSummaryWidgets(sel),
      'index_tabs_summary': parseIndexTabsSummary(sel),
      'table_header_summary': parseTableHeaderSummary(sel),
      'crypto_exchanges_local': parseCryptoExchanges(sel),
      'technicals': parseTechnicals(sel),
      'economic_calendar': parseCalendar(sel),
      'header_news': parseHeaderNews(sel),
      'world_map': parseWorldMap(sel),
    };
  }

  Future<Map<String, dynamic>> run() async {
    final html = await fetch();
    return parse(html);
  }

  void close() {
    if (_ownsClient) _client.close();
  }
}