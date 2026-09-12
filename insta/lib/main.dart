// ============================================================
// نبض بازار — اپلیکیشن قیمت طلا، سکه، ارز و رمزارز
// فایل: lib/main.dart   (فایل tgju_scraper.dart کنار همین فایل باشد)
// ============================================================
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';

import 'tgju_scraper.dart';

// ============================================================
// main
// ============================================================
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LiquidGlassWidgets.initialize();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarContrastEnforced: false,
    ),
  );
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  final settings = AppSettings();
  await settings.load();
  runApp(TgjuApp(settings: settings));
}

// ============================================================
// App
// ============================================================
class TgjuApp extends StatelessWidget {
  final AppSettings settings;
  const TgjuApp({super.key, required this.settings});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AppSettings>.value(value: settings),
        ChangeNotifierProvider<MarketDataProvider>(
          create: (_) => MarketDataProvider(settings),
        ),
      ],
      child: Consumer<AppSettings>(
        builder: (context, s, _) {
          return MaterialApp(
            title: 'نبض بازار',
            debugShowCheckedModeBanner: false,
            locale: const Locale('fa'),
            supportedLocales: const [Locale('fa')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            themeMode: s.themeModeValue,
            theme: _buildTheme(s, Brightness.light),
            darkTheme: _buildTheme(s, Brightness.dark),
            home: const MainScreen(),
          );
        },
      ),
    );
  }

  ThemeData _buildTheme(AppSettings s, Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: s.seedColor,
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: 'Vazir',
      scaffoldBackgroundColor: brightness == Brightness.light
          ? const Color(0xFFF4F6FB)
          : const Color(0xFF0B1020),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: 'Vazir',
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: scheme.onSurface,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(s.cardRadius),
        ),
      ),
    );
  }
}

// ============================================================
// رنگ‌های قابل انتخاب
// ============================================================
const List<Color> kPalette = [
  Color(0xFF00897B), // فیروزه‌ای
  Color(0xFF1E88E5), // آبی
  Color(0xFF8E24AA), // بنفش
  Color(0xFFE53935), // قرمز
  Color(0xFFFB8C00), // نارنجی
  Color(0xFF43A047), // سبز
  Color(0xFFD81B60), // صورتی
  Color(0xFF3949AB), // سرمه‌ای
  Color(0xFFF9A825), // طلایی
];
const List<String> kPaletteNames = [
  'فیروزه‌ای', 'آبی', 'بنفش', 'قرمز', 'نارنجی', 'سبز', 'صورتی', 'سرمه‌ای', 'طلایی',
];

// ============================================================
// تنظیمات برنامه (ذخیره در SharedPreferences)
// ============================================================
class AppSettings extends ChangeNotifier {
  int themeMode = 0; // 0=سیستم 1=روشن 2=تاریک
  int seedIndex = 0;
  double fontScale = 1.0;
  double cardRadius = 20;
  bool compact = false;
  bool animations = true;
  bool persianDigits = true;
  int priceUnit = 1; // 0=ریال 1=تومان
  bool showPct = true;
  bool showChangeVal = false;
  bool showHighLow = true;
  bool showTime = true;
  int sortMode = 0; // 0 پیش‌فرض 1 گران‌ترین 2 ارزان‌ترین 3 بیشترین تغییر 4 الفبا
  bool favoritesFirst = true;
  bool tickerOn = true;
  bool showImages = true;
  bool navLabels = true;
  double navIconSize = 24;
  double navWidthPct = 100;
  double navBottomPad = 16;
  int navColorIdx = -1; // -1 = رنگ پوسته
  int autoRefreshMin = 0; // 0 = خاموش
  bool useCache = true;

  List<String> tabs = ['home', 'gold', 'coin', 'charts', 'settings'];
  Set<String> favorites = {};
  Map<String, Map<String, dynamic>> alerts = {}; // slug -> {v, dir}

  ThemeMode get themeModeValue =>
      themeMode == 1 ? ThemeMode.light : themeMode == 2 ? ThemeMode.dark : ThemeMode.system;
  Color get seedColor => kPalette[seedIndex % kPalette.length];
  Color get navActiveColor => navColorIdx < 0 ? seedColor : kPalette[navColorIdx % kPalette.length];

  List<String> get optionalTabs =>
      tabs.where((t) => t != 'home' && t != 'settings').toList();

  void setOptionalTabs(List<String> opt) {
    tabs = ['home', ...opt, 'settings'];
    save();
  }

  void toggleTab(String id) {
    final opt = optionalTabs;
    if (opt.contains(id)) {
      if (opt.length <= 1) return;
      opt.remove(id);
    } else {
      if (opt.length >= 3) return;
      opt.add(id);
    }
    setOptionalTabs(opt);
  }

  void moveTab(String id, int delta) {
    final opt = optionalTabs;
    final i = opt.indexOf(id);
    final j = i + delta;
    if (i < 0 || j < 0 || j >= opt.length) return;
    final t = opt[i];
    opt[i] = opt[j];
    opt[j] = t;
    setOptionalTabs(opt);
  }

  void toggleFavorite(String slug) {
    if (!favorites.add(slug)) favorites.remove(slug);
    save();
  }

  void setAlert(String slug, double value, String dir) {
    alerts[slug] = {'v': value, 'dir': dir};
    save();
  }

  void removeAlert(String slug) {
    alerts.remove(slug);
    save();
  }

  void reset() {
    themeMode = 0; seedIndex = 0; fontScale = 1.0; cardRadius = 20;
    compact = false; animations = true; persianDigits = true; priceUnit = 1;
    showPct = true; showChangeVal = false; showHighLow = true; showTime = true;
    sortMode = 0; favoritesFirst = true; tickerOn = true; showImages = true;
    navLabels = true; navIconSize = 24; navWidthPct = 100; navBottomPad = 16;
    navColorIdx = -1; autoRefreshMin = 0; useCache = true;
    tabs = ['home', 'gold', 'coin', 'charts', 'settings'];
    save();
  }

  Map<String, dynamic> _toJson() => {
        'themeMode': themeMode, 'seedIndex': seedIndex, 'fontScale': fontScale,
        'cardRadius': cardRadius, 'compact': compact, 'animations': animations,
        'persianDigits': persianDigits, 'priceUnit': priceUnit, 'showPct': showPct,
        'showChangeVal': showChangeVal, 'showHighLow': showHighLow, 'showTime': showTime,
        'sortMode': sortMode, 'favoritesFirst': favoritesFirst, 'tickerOn': tickerOn,
        'showImages': showImages, 'navLabels': navLabels, 'navIconSize': navIconSize,
        'navWidthPct': navWidthPct, 'navBottomPad': navBottomPad,
        'navColorIdx': navColorIdx, 'autoRefreshMin': autoRefreshMin,
        'useCache': useCache, 'tabs': tabs,
        'favorites': favorites.toList(), 'alerts': alerts,
      };

  void _fromJson(Map<String, dynamic> j) {
    themeMode = j['themeMode'] ?? themeMode;
    seedIndex = j['seedIndex'] ?? seedIndex;
    fontScale = (j['fontScale'] ?? fontScale).toDouble();
    cardRadius = (j['cardRadius'] ?? cardRadius).toDouble();
    compact = j['compact'] ?? compact;
    animations = j['animations'] ?? animations;
    persianDigits = j['persianDigits'] ?? persianDigits;
    priceUnit = j['priceUnit'] ?? priceUnit;
    showPct = j['showPct'] ?? showPct;
    showChangeVal = j['showChangeVal'] ?? showChangeVal;
    showHighLow = j['showHighLow'] ?? showHighLow;
    showTime = j['showTime'] ?? showTime;
    sortMode = j['sortMode'] ?? sortMode;
    favoritesFirst = j['favoritesFirst'] ?? favoritesFirst;
    tickerOn = j['tickerOn'] ?? tickerOn;
    showImages = j['showImages'] ?? showImages;
    navLabels = j['navLabels'] ?? navLabels;
    navIconSize = (j['navIconSize'] ?? navIconSize).toDouble();
    navWidthPct = (j['navWidthPct'] ?? navWidthPct).toDouble();
    navBottomPad = (j['navBottomPad'] ?? navBottomPad).toDouble();
    navColorIdx = j['navColorIdx'] ?? navColorIdx;
    autoRefreshMin = j['autoRefreshMin'] ?? autoRefreshMin;
    useCache = j['useCache'] ?? useCache;
    if (j['tabs'] is List) tabs = List<String>.from(j['tabs']);
    if (j['favorites'] is List) favorites = Set<String>.from(j['favorites']);
    if (j['alerts'] is Map) {
      alerts = (j['alerts'] as Map).map(
        (k, v) => MapEntry(k.toString(), Map<String, dynamic>.from(v as Map)),
      );
    }
  }

  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString('app_settings_v1');
      if (raw != null) _fromJson(jsonDecode(raw));
    } catch (_) {}
    notifyListeners();
  }

  Future<void> save() async {
    notifyListeners();
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString('app_settings_v1', jsonEncode(_toJson()));
    } catch (_) {}
  }
}

// ============================================================
// مدل یک بازار
// ============================================================
class MarketItem {
  final String slug;
  final String title;
  final String category; // gold | coin | currency | crypto
  final double? priceRial;
  final double? priceUsd;
  final double? change;
  final double? changePct;
  final double? low;
  final double? high;
  final double? firstRate;
  final String? time;
  final String? direction;
  final List<Map<String, dynamic>> history;

  const MarketItem({
    required this.slug,
    required this.title,
    required this.category,
    this.priceRial,
    this.priceUsd,
    this.change,
    this.changePct,
    this.low,
    this.high,
    this.firstRate,
    this.time,
    this.direction,
    this.history = const [],
  });

  factory MarketItem.fromMap(String slug, Map<String, dynamic> m) {
    final title = cleanText(m['title']);
    final price = (m['price'] as num?)?.toDouble();
    final priceIrr = (m['price_irr'] as num?)?.toDouble();
    final hist = (m['history'] as List?)
            ?.map((e) => Map<String, dynamic>.from(e as Map))
            .toList() ??
        <Map<String, dynamic>>[];
    return MarketItem(
      slug: slug,
      title: title.isEmpty ? slug : title,
      category: _categoryOf(slug, title),
      priceRial: priceIrr ?? price,
      priceUsd: (m['price_usd'] as num?)?.toDouble(),
      change: (m['change'] as num?)?.toDouble(),
      changePct: (m['change_pct'] as num?)?.toDouble(),
      low: (m['low'] as num?)?.toDouble(),
      high: (m['high'] as num?)?.toDouble(),
      firstRate: (m['first_rate_today'] as num?)?.toDouble(),
      time: m['time']?.toString(),
      direction: m['direction']?.toString(),
      history: hist,
    );
  }

  double? displayPrice(int unit) =>
      priceRial == null ? null : (unit == 1 ? priceRial! / 10 : priceRial!);
}

String _categoryOf(String slug, String title) {
  const cryptoSlugs = ['btc', 'eth', 'usdt', 'doge', 'ada', 'xrp', 'bnb', 'sol', 'shib', 'trx', 'crypto', 'bitcoin', 'tether'];
  const cryptoKeys = ['بیت کوین', 'بیت‌کوین', 'اتریوم', 'تتر', 'ریپل', 'دوج', 'کاردانو', 'لایت', 'بایننس', 'سولانا', 'شیبا', 'ترون', 'پولکادات', 'چین لینک', 'چین‌لینک', 'استلار', 'بیت‌کش', 'آوالانچ', 'یونی', 'پپه'];
  final s = slug.toLowerCase();
  if (cryptoSlugs.any(s.contains) || cryptoKeys.any(title.contains)) return 'crypto';
  if (title.contains('سکه')) return 'coin';
  if (title.contains('طلا') || title.contains('مثقال') || title.contains('اونس') ||
      title.contains('انس') || title.contains('نقره') || s.contains('gold') || s.contains('ons')) {
    return 'gold';
  }
  return 'currency';
}

const Map<String, (String, IconData, Color)> kTabMeta = {
  'home': ('خانه', Icons.home_rounded, Color(0xFF00897B)),
  'gold': ('طلا', Icons.stars_rounded, Color(0xFFF9A825)),
  'coin': ('سکه', Icons.monetization_on_rounded, Color(0xFFFB8C00)),
  'currency': ('ارز', Icons.account_balance_wallet_rounded, Color(0xFF1E88E5)),
  'crypto': ('رمزارز', Icons.currency_bitcoin_rounded, Color(0xFF8E24AA)),
  'charts': ('نمودار', Icons.show_chart_rounded, Color(0xFF43A047)),
  'news': ('اخبار', Icons.newspaper_rounded, Color(0xFFE53935)),
  'settings': ('تنظیمات', Icons.settings_rounded, Color(0xFF546E7A)),
};

// ============================================================
// ارائه‌دهنده داده‌ها — فقط یک درخواست شبکه در هر به‌روزرسانی
// ============================================================
class MarketDataProvider extends ChangeNotifier {
  final AppSettings settings;
  MarketDataProvider(this.settings);

  Map<String, dynamic>? data;
  List<MarketItem> items = [];
  List<MarketItem> infoBarItems = [];
  bool loading = false;
  String? error;
  DateTime? lastUpdated;
  bool fromCache = false;
  int countdown = 0;

  Timer? _tickTimer;
  final TgjuScraper _scraper = TgjuScraper();
  final List<String> _alertQueue = [];
  final Set<String> _notifiedAlerts = {};
  bool _inited = false;

  Future<void> init() async {
    if (_inited) return;
    _inited = true;
    await _loadCache();
    await refreshIfStale();
  }

  Future<File?> get _cacheFile async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      return File('${dir.path}/tgju_cache.html');
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadCache() async {
    if (!settings.useCache) return;
    try {
      final f = await _cacheFile;
      if (f == null || !await f.exists()) return;
      final html = await f.readAsString();
      final p = await SharedPreferences.getInstance();
      final t = p.getInt('cache_time_ms');
      final parsed = _scraper.parse(html);
      _applyData(
        parsed,
        fromCache: true,
        time: t != null ? DateTime.fromMillisecondsSinceEpoch(t) : null,
      );
    } catch (_) {}
  }

  Future<void> refreshIfStale() async {
    final stale = lastUpdated == null ||
        DateTime.now().difference(lastUpdated!) > const Duration(minutes: 2);
    if (stale) await refresh(force: true);
  }

  Future<void> refresh({bool force = false}) async {
    if (loading) return;
    if (!force &&
        lastUpdated != null &&
        DateTime.now().difference(lastUpdated!) < const Duration(seconds: 30)) {
      return;
    }
    loading = true;
    error = null;
    notifyListeners();
    try {
      final html = await _scraper.fetch(); // ← تنها درخواست شبکه
      final parsed = _scraper.parse(html);
      final now = DateTime.now();
      _applyData(parsed, fromCache: false, time: now);
      try {
        final f = await _cacheFile;
        if (f != null) {
          await f.writeAsString(html);
          final p = await SharedPreferences.getInstance();
          await p.setInt('cache_time_ms', now.millisecondsSinceEpoch);
        }
      } catch (_) {}
      _checkAlerts();
    } catch (_) {
      error = data == null
          ? 'خطا در دریافت اطلاعات. اتصال اینترنت خود را بررسی کنید.'
          : 'به‌روزرسانی ناموفق بود؛ داده‌های فعلی نمایش داده می‌شوند.';
    }
    loading = false;
    notifyListeners();
  }

  void _applyData(Map<String, dynamic> parsed, {required bool fromCache, DateTime? time}) {
    data = parsed;
    this.fromCache = fromCache;
    lastUpdated = time ?? DateTime.now();
    final markets = (parsed['markets'] as Map?)?.cast<String, dynamic>() ?? {};
    items = markets.entries
        .map((e) => MarketItem.fromMap(e.key, Map<String, dynamic>.from(e.value as Map)))
        .toList();
    final ib = (parsed['info_bar'] as Map?)?.cast<String, dynamic>() ?? {};
    infoBarItems = ib.entries
        .map((e) => MarketItem.fromMap(e.key, Map<String, dynamic>.from(e.value as Map)))
        .where((i) => i.priceRial != null)
        .toList();
    notifyListeners();
  }

  void configureAutoRefresh(int minutes) {
    _tickTimer?.cancel();
    _tickTimer = null;
    countdown = 0;
    if (minutes > 0) {
      countdown = minutes * 60;
      _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (countdown > 0) {
          countdown--;
          if (countdown == 0) {
            countdown = minutes * 60;
            refresh(force: true);
          }
          notifyListeners();
        }
      });
    }
    notifyListeners();
  }

  void _checkAlerts() {
    settings.alerts.forEach((slug, cfg) {
      final item = findBySlug(slug);
      if (item == null) return;
      final price = item.priceRial;
      final target = (cfg['v'] as num?)?.toDouble();
      final dir = cfg['dir']?.toString();
      if (price == null || target == null) return;
      final key = '$slug|$target|$dir';
      final hit = dir == 'above' ? price >= target : price <= target;
      if (hit && !_notifiedAlerts.contains(key)) {
        _notifiedAlerts.add(key);
        _alertQueue.add(
          'هشدار قیمت: «${item.title}» به ${formatNumber(target)} ${unitWord(settings)} رسید.',
        );
      }
    });
  }

  List<String> popAlerts() {
    if (_alertQueue.isEmpty) return const [];
    final l = List<String>.from(_alertQueue);
    _alertQueue.clear();
    return l;
  }

  MarketItem? findBySlug(String slug) {
    for (final i in items) {
      if (i.slug == slug) return i;
    }
    return null;
  }

  Future<void> clearCache() async {
    try {
      final f = await _cacheFile;
      if (f != null && await f.exists()) await f.delete();
      final p = await SharedPreferences.getInstance();
      await p.remove('cache_time_ms');
    } catch (_) {}
  }

  // ---------- دسترسی به بخش‌های مختلف داده ----------
  List<Map<String, dynamic>> _listOfMaps(String key) =>
      (data?[key] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [];
  Map<String, Map<String, dynamic>> _mapOfMaps(String key) {
    final m = (data?[key] as Map?)?.cast<String, dynamic>() ?? {};
    return m.map((k, v) => MapEntry(k, Map<String, dynamic>.from(v as Map)));
  }

  Map<String, Map<String, dynamic>> get summaryWidgets => _mapOfMaps('summary_widgets');
  Map<String, Map<String, dynamic>> get tableHeaderSummary => _mapOfMaps('table_header_summary');
  Map<String, Map<String, dynamic>> get indexTabsSummary => _mapOfMaps('index_tabs_summary');
  List<Map<String, dynamic>> get cryptoExchanges => _listOfMaps('crypto_exchanges_local');
  List<Map<String, dynamic>> get technicals => _listOfMaps('technicals');
  List<Map<String, dynamic>> get calendar => _listOfMaps('economic_calendar');
  List<Map<String, dynamic>> get headerNews => _listOfMaps('header_news');
  List<Map<String, dynamic>> get worldMap => _listOfMaps('world_map');
  String? get serverTime {
    final st = data?['meta']?['server_time'];
    if (st is Map) return st['value']?.toString();
    return null;
  }

  /// لیست فیلتر + مرتب‌شده برای تب‌ها
  List<MarketItem> filtered(String category, String query) {
    var list = items
        .where((i) => category == 'all' || i.category == category)
        .toList();
    final q = query.trim();
    if (q.isNotEmpty) list = list.where((i) => i.title.contains(q)).toList();
    switch (settings.sortMode) {
      case 1:
        list.sort((a, b) => (b.priceRial ?? 0).compareTo(a.priceRial ?? 0));
      case 2:
        list.sort((a, b) => (a.priceRial ?? double.infinity).compareTo(b.priceRial ?? double.infinity));
      case 3:
        list.sort((a, b) => (b.changePct ?? -999).compareTo(a.changePct ?? -999));
      case 4:
        list.sort((a, b) => a.title.compareTo(b.title));
    }
    if (settings.favoritesFirst) {
      final fav = list.where((i) => settings.favorites.contains(i.slug)).toList();
      final rest = list.where((i) => !settings.favorites.contains(i.slug)).toList();
      list = [...fav, ...rest];
    }
    return list;
  }

  List<MarketItem> get topMovers {
    final l = items.where((i) => i.changePct != null).toList()
      ..sort((a, b) => b.changePct!.abs().compareTo(a.changePct!.abs()));
    return l.take(8).toList();
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    _scraper.close();
    super.dispose();
  }
}

// ============================================================
// ابزارهای قالب‌بندی فارسی
// ============================================================
const List<String> _faDigits = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];

String toFa(String s) {
  final sb = StringBuffer();
  for (final r in s.runes) {
    if (r >= 48 && r <= 57) {
      sb.write(_faDigits[r - 48]);
    } else if (r == 46) {
      sb.write('٫');
    } else {
      sb.writeCharCode(r);
    }
  }
  return sb.toString();
}

String formatNumber(double? v, {bool fa = true, int dec = 0}) {
  if (v == null) return '—';
  final fixed = v.abs().toStringAsFixed(dec);
  final parts = fixed.split('.');
  final intPart = parts[0];
  final buf = StringBuffer();
  for (var i = 0; i < intPart.length; i++) {
    if (i > 0 && (intPart.length - i) % 3 == 0) buf.write('٬');
    buf.write(intPart[i]);
  }
  var out = buf.toString();
  if (parts.length > 1) out += '.${parts[1]}';
  if (v < 0) out = '-$out';
  return fa ? toFa(out) : out;
}

String unitWord(AppSettings s) => s.priceUnit == 1 ? 'تومان' : 'ریال';

String fmtPrice(BuildContext context, double? rial, {int dec = 0}) {
  final s = context.watch<AppSettings>();
  if (rial == null) return '—';
  final v = s.priceUnit == 1 ? rial / 10 : rial;
  return formatNumber(v, fa: s.persianDigits, dec: dec);
}

String fmtClock(DateTime t, bool fa) {
  final s = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  return fa ? toFa(s) : s;
}

Color changeColor(double? pct) =>
    pct == null || pct == 0 ? Colors.grey : (pct > 0 ? const Color(0xFF16A34A) : const Color(0xFFDC2626));

double? parseUserNumber(String raw) {
  var s = faToEnDigits(raw).replaceAll(',', '').replaceAll('٬', '').trim();
  s = s.replaceAll(RegExp(r'[^\d.\-]'), '');
  return double.tryParse(s);
}

Future<void> openUrl(String url) async {
  try {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  } catch (_) {}
}

// ============================================================
// صفحه اصلی با نوار پایین شیشه‌ای
// ============================================================
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  int _lastAuto = -1;
  String? _lastError;
  bool _listenersAttached = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_listenersAttached) return;
    _listenersAttached = true;
    final s = context.read<AppSettings>();
    final p = context.read<MarketDataProvider>();
    p.init();
    _lastAuto = s.autoRefreshMin;
    p.configureAutoRefresh(_lastAuto);
    s.addListener(_onSettings);
    p.addListener(_onData);
  }

  void _onSettings() {
    final s = context.read<AppSettings>();
    if (s.autoRefreshMin != _lastAuto) {
      _lastAuto = s.autoRefreshMin;
      context.read<MarketDataProvider>().configureAutoRefresh(_lastAuto);
    }
    if (_selectedIndex >= s.tabs.length) {
      _selectedIndex = 0;
    }
  }

  void _onData() {
    final p = context.read<MarketDataProvider>();
    final msgs = p.popAlerts();
    for (final m in msgs) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [
            const Icon(Icons.notifications_active_rounded, color: Colors.amber),
            const SizedBox(width: 8),
            Expanded(child: Text(m, style: const TextStyle(fontFamily: 'Vazir'))),
          ]),
        ),
      );
    }
    if (p.error != null && p.error != _lastError) {
      _lastError = p.error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(p.error!, style: const TextStyle(fontFamily: 'Vazir'))),
      );
    } else if (p.error == null) {
      _lastError = null;
    }
  }

  @override
  void dispose() {
    if (_listenersAttached) {
      context.read<AppSettings>().removeListener(_onSettings);
      context.read<MarketDataProvider>().removeListener(_onData);
    }
    super.dispose();
  }

  Widget _screenOf(String id) {
    switch (id) {
      case 'gold':
        return const MarketsScreen(category: 'gold');
      case 'coin':
        return const MarketsScreen(category: 'coin');
      case 'currency':
        return const MarketsScreen(category: 'currency');
      case 'crypto':
        return const MarketsScreen(category: 'crypto');
      case 'charts':
        return const ChartsScreen();
      case 'news':
        return const NewsScreen();
      case 'settings':
        return const SettingsScreen();
      default:
        return const HomeScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppSettings>();
    final scheme = Theme.of(context).colorScheme;
    final tabIds = s.tabs;
    if (_selectedIndex >= tabIds.length) _selectedIndex = 0;

    const double menuBottomPaddingBase = 16.0;
    final menuBottomPadding = s.navBottomPad;
    final menuWidthPercent = s.navWidthPct;
    final menuColor = s.navActiveColor;
    final screenWidth = MediaQuery.of(context).size.width;
    final widthFactor = (menuWidthPercent / 100).clamp(0.4, 1.0);
    final horizontalPadding = (screenWidth * (1 - widthFactor)) / 2;
    Color iconColor(int index) =>
        _selectedIndex == index ? menuColor : menuColor.withOpacity(0.55);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarContrastEnforced: false,
      ),
      child: Scaffold(
        extendBody: true,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(s.fontScale)),
          child: AnimatedSwitcher(
            duration: Duration(milliseconds: s.animations ? 350 : 1),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              final tween = Tween<Offset>(
                begin: const Offset(0.06, 0),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              );
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(position: tween, child: child),
              );
            },
            child: KeyedSubtree(
              key: ValueKey(tabIds[_selectedIndex]),
              child: _screenOf(tabIds[_selectedIndex]),
            ),
          ),
        ),
        bottomNavigationBar: Padding(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            0,
            horizontalPadding,
            menuBottomPaddingBase == 0 ? menuBottomPadding : menuBottomPadding,
          ),
          child: DefaultTextStyle(
            style: TextStyle(
              color: menuColor,
              fontSize: 12,
              fontFamily: 'Vazir',
            ),
            child: IconTheme(
              data: IconThemeData(color: scheme.primary, size: s.navIconSize),
              child: GlassTabBar.bottom(
                selectedIndex: _selectedIndex,
                onTabSelected: (index) {
                  if (index == _selectedIndex) return;
                  setState(() => _selectedIndex = index);
                },
                tabs: [
                  for (var i = 0; i < tabIds.length; i++)
                    GlassTab(
                      icon: Icon(
                        kTabMeta[tabIds[i]]?.$2 ?? Icons.circle,
                        color: iconColor(i),
                        size: s.navIconSize,
                      ),
                      label: s.navLabels ? (kTabMeta[tabIds[i]]?.$1 ?? '') : '',
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// ویجت‌های مشترک
// ============================================================
Widget appCard(
  BuildContext context, {
  required Widget child,
  EdgeInsets? padding,
  VoidCallback? onTap,
}) {
  final s = context.watch<AppSettings>();
  final scheme = Theme.of(context).colorScheme;
  return Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(s.cardRadius),
      child: Container(
        padding: padding ??
            EdgeInsets.all(s.compact ? 8 : 14),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(s.cardRadius),
          border: Border.all(color: scheme.outlineVariant.withOpacity(0.5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: child,
      ),
    ),
  );
}

class SectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SectionTitle(this.text, {super.key, this.trailing});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
      child: Row(
        children: [
          Container(
            width: 4, height: 18,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class ChangeChip extends StatelessWidget {
  final double? pct;
  final bool small;
  const ChangeChip(this.pct, {super.key, this.small = false});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppSettings>();
    final c = changeColor(pct);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 6 : 8,
        vertical: small ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: c.withOpacity(0.12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (pct != null && pct != 0)
            Icon(
              pct! > 0 ? Icons.arrow_drop_up_rounded : Icons.arrow_drop_down_rounded,
              color: c,
              size: small ? 14 : 18,
            ),
          Text(
            pct == null ? '—' : '${formatNumber(pct!.abs(), fa: s.persianDigits, dec: 2)}٪',
            style: TextStyle(
              color: c,
              fontSize: small ? 10 : 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class CatIcon extends StatelessWidget {
  final String category;
  final double size;
  const CatIcon(this.category, {super.key, this.size = 42});
  @override
  Widget build(BuildContext context) {
    final meta = kTabMeta[category] ?? kTabMeta['currency']!;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: meta.$3.withOpacity(0.14),
        shape: BoxShape.circle,
      ),
      child: Icon(meta.$2, color: meta.$3, size: size * 0.55),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String text;
  const EmptyState(this.icon, this.text, {super.key});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: Colors.grey.withOpacity(0.5)),
            const SizedBox(height: 12),
            Text(text,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final base = dark ? const Color(0xFF1A2236) : Colors.white;
    return Center(
      child: SizedBox(
        width: 260,
        child: Shimmer.fromColors(
          baseColor: base,
          highlightColor: dark ? const Color(0xFF2A3350) : const Color(0xFFE8ECF4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(height: 90, decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(20))),
              const SizedBox(height: 12),
              Container(height: 64, decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(20))),
              const SizedBox(height: 12),
              Container(height: 64, decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(20))),
              const SizedBox(height: 12),
              Container(height: 64, decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(20))),
              const SizedBox(height: 24),
              Text('در حال دریافت اطلاعات بازار...',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}

class ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const ErrorView({super.key, required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('تلاش مجدد'),
            ),
          ],
        ),
      ),
    );
  }
}

/// دروازه داده: اگر داده نداریم لودینگ/خطا نشان بده
Widget dataGate(BuildContext context, Widget Function() builder) {
  final p = context.watch<MarketDataProvider>();
  if (p.data == null) {
    if (p.error != null) {
      return ErrorView(message: p.error!, onRetry: () => p.refresh(force: true));
    }
    return const LoadingView();
  }
  return builder();
}

// ============================================================
// کاشی یک بازار
// ============================================================
class MarketTile extends StatelessWidget {
  final MarketItem item;
  const MarketTile({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppSettings>();
    final isFav = s.favorites.contains(item.slug);
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(bottom: s.compact ? 6 : 10),
      child: appCard(
        context,
        onTap: () => showMarketDetail(context, item),
        child: Row(
          children: [
            CatIcon(item.category),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (s.showTime && item.time != null && item.time!.isNotEmpty) ...[
                        Icon(Icons.schedule_rounded, size: 13, color: Colors.grey.shade500),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            item.time!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                          ),
                        ),
                      ] else
                        Text(
                          item.category == 'gold'
                              ? 'بازار طلا'
                              : item.category == 'coin'
                                  ? 'بازار سکه'
                                  : item.category == 'crypto'
                                      ? 'رمزارز'
                                      : 'بازار ارز',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text.rich(
                  TextSpan(children: [
                    TextSpan(
                      text: fmtPrice(context, item.priceRial),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    TextSpan(
                      text: ' ${unitWord(s)}',
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                    ),
                  ]),
                ),
                const SizedBox(height: 5),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (s.showChangeVal && item.change != null) ...[
                      Text(
                        '${item.direction == 'low' ? '−' : '+'}${fmtPrice(context, item.change!.abs())}',
                        style: TextStyle(fontSize: 10, color: changeColor(item.changePct)),
                      ),
                      const SizedBox(width: 6),
                    ],
                    if (s.showPct) ChangeChip(item.changePct, small: true),
                  ],
                ),
              ],
            ),
            SizedBox(
              width: 36,
              child: IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: () => s.toggleFavorite(item.slug),
                icon: Icon(
                  isFav ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: isFav ? Colors.amber : Colors.grey.shade400,
                  size: 22,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// صفحه جزئیات بازار (Bottom Sheet)
// ============================================================
void showMarketDetail(BuildContext context, MarketItem item) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => MarketDetailSheet(item: item),
  );
}

class MarketDetailSheet extends StatefulWidget {
  final MarketItem item;
  const MarketDetailSheet({super.key, required this.item});
  @override
  State<MarketDetailSheet> createState() => _MarketDetailSheetState();
}

class _MarketDetailSheetState extends State<MarketDetailSheet> {
  final _ctrl = TextEditingController();
  String dir = 'above';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppSettings>();
    final scheme = Theme.of(context).colorScheme;
    final item = widget.item;
    final isFav = s.favorites.contains(item.slug);
    final existing = s.alerts[item.slug];
    final prices = item.history
        .map((h) => (h['price'] as num?)?.toDouble())
        .whereType<double>()
        .toList();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: ListView(
          controller: scrollCtrl,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Center(
              child: Container(
                width: 44, height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                CatIcon(item.category, size: 48),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.title,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                      if (item.time != null && item.time!.isNotEmpty)
                        Text('آخرین به‌روزرسانی: ${item.time}',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => s.toggleFavorite(item.slug),
                  icon: Icon(
                    isFav ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: isFav ? Colors.amber : Colors.grey,
                    size: 28,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [scheme.primary.withOpacity(0.12), scheme.secondary.withOpacity(0.06)],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
                borderRadius: BorderRadius.circular(s.cardRadius),
              ),
              child: Column(
                children: [
                  Text.rich(
                    TextSpan(children: [
                      TextSpan(
                        text: fmtPrice(context, item.priceRial),
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: scheme.primary,
                        ),
                      ),
                      TextSpan(
                        text: ' ${unitWord(s)}',
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (s.showPct) ChangeChip(item.changePct),
                      if (item.priceUsd != null) ...[
                        const SizedBox(width: 10),
                        Text(
                          '≈ ${formatNumber(item.priceUsd, fa: s.persianDigits, dec: 2)} دلار',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (s.showHighLow || item.firstRate != null)
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  if (item.high != null)
                    _InfoPill('بیشترین', fmtPrice(context, item.high), const Color(0xFF16A34A)),
                  if (item.low != null)
                    _InfoPill('کمترین', fmtPrice(context, item.low), const Color(0xFFDC2626)),
                  if (item.firstRate != null)
                    _InfoPill('اولین نرخ امروز', fmtPrice(context, item.firstRate), scheme.primary),
                  if (item.priceUsd != null)
                    _InfoPill('قیمت دلاری', formatNumber(item.priceUsd, fa: s.persianDigits, dec: 2), scheme.secondary),
                ],
              ),
            if (prices.length >= 2) ...[
              const SectionTitle('روند امروز'),
              SizedBox(
                height: 180,
                child: appCard(
                  context,
                  child: _HistoryChart(
                    prices: prices,
                    color: changeColor(item.changePct),
                  ),
                ),
              ),
            ],
            const SectionTitle('هشدار قیمت'),
            appCard(
              context,
              child: Column(
                children: [
                  if (existing != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.notifications_active_rounded,
                              color: Colors.amber, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'هشدار فعلی: ${existing['dir'] == 'above' ? 'صعود به بالای' : 'نزول به پایین'} '
                              '${formatNumber((existing['v'] as num?)?.toDouble(), fa: s.persianDigits)} ${unitWord(s)}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            onPressed: () => s.removeAlert(item.slug),
                            icon: const Icon(Icons.close_rounded, size: 18),
                          ),
                        ],
                      ),
                    ),
                  TextField(
                    controller: _ctrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9۰-۹٠-٩.,٬]')),
                    ],
                    decoration: InputDecoration(
                      hintText: 'قیمت هدف به ${unitWord(s)}',
                      prefixIcon: const Icon(Icons.price_change_rounded),
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'above', label: Text('صعود به بالای')),
                      ButtonSegment(value: 'below', label: Text('نزول به پایین')),
                    ],
                    selected: {dir},
                    showSelectedIcon: false,
                    onSelectionChanged: (v) => setState(() => dir = v.first),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        final v = parseUserNumber(_ctrl.text);
                        if (v == null || v <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('لطفاً یک عدد معتبر وارد کنید.')),
                          );
                          return;
                        }
                        final targetRial = s.priceUnit == 1 ? v * 10 : v;
                        s.setAlert(item.slug, targetRial, dir);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('هشدار قیمت ثبت شد.')),
                        );
                      },
                      icon: const Icon(Icons.notifications_active_rounded),
                      label: const Text('ثبت هشدار'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _InfoPill(this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.09),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}

class _HistoryChart extends StatelessWidget {
  final List<double> prices;
  final Color color;
  const _HistoryChart({required this.prices, required this.color});
  @override
  Widget build(BuildContext context) {
    final spots = <FlSpot>[];
    for (var i = 0; i < prices.length; i++) {
      spots.add(FlSpot(i.toDouble(), prices[i]));
    }
    final mn = prices.reduce(math.min);
    final mx = prices.reduce(math.max);
    final pad = (mx - mn) * 0.15 + 1;
    return LineChart(
      LineChartData(
        minY: mn - pad,
        maxY: mx + pad,
        lineTouchData: const LineTouchData(enabled: false),
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.25,
            color: color,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: true, color: color.withOpacity(0.12)),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// صفحه خانه
// ============================================================
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late PageController _tickerCtrl;
  Timer? _tickerTimer;
  int _tickerPage = 5000;

  @override
  void initState() {
    super.initState();
    _tickerCtrl = PageController(initialPage: _tickerPage);
  }

  void _startTicker(AppSettings s) {
    _tickerTimer?.cancel();
    if (s.tickerOn && s.animations) {
      _tickerTimer = Timer.periodic(const Duration(seconds: 4), (_) {
        if (_tickerCtrl.hasClients) {
          _tickerPage++;
          _tickerCtrl.animateToPage(
            _tickerPage,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _tickerTimer?.cancel();
    _tickerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppSettings>();
    final p = context.watch<MarketDataProvider>();
    return dataGate(context, () {
      _startTicker(s);
      final scheme = Theme.of(context).colorScheme;
      final favItems =
          p.items.where((i) => s.favorites.contains(i.slug)).take(6).toList();

      return RefreshIndicator(
        onRefresh: () => p.refresh(force: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 130),
          children: [
            // ---------- سربرگ ----------
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [scheme.primary.withOpacity(0.16), scheme.secondary.withOpacity(0.05)],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
                borderRadius: BorderRadius.circular(s.cardRadius + 4),
                border: Border.all(color: scheme.primary.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [scheme.primary, scheme.secondary],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.show_chart_rounded, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('نبض بازار',
                            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 19)),
                        const SizedBox(height: 3),
                        Text(
                          p.lastUpdated == null
                              ? 'در حال دریافت...'
                              : 'آخرین به‌روزرسانی: ${fmtClock(p.lastUpdated!, s.persianDigits)}${p.fromCache ? ' (کش)' : ''}',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        ),
                        if (p.countdown > 0)
                          Text(
                            'به‌روزرسانی خودکار تا ${toFa('${p.countdown ~/ 60}:${(p.countdown % 60).toString().padLeft(2, '0')}')} دیگر',
                            style: TextStyle(fontSize: 10, color: scheme.primary),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: p.loading ? null : () => p.refresh(force: true),
                    icon: p.loading
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
            ),
            if (p.lastUpdated != null &&
                DateTime.now().difference(p.lastUpdated!) > const Duration(minutes: 10))
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.hourglass_bottom_rounded, size: 16, color: Colors.orange),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'داده‌ها ممکن است قدیمی باشند. برای دریافت آخرین قیمت‌ها به‌روزرسانی کنید.',
                          style: TextStyle(fontSize: 11, color: Colors.orange.shade900),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            // ---------- نوار متحرک ----------
            if (s.tickerOn && p.infoBarItems.isNotEmpty) ...[
              const SizedBox(height: 14),
              SizedBox(
                height: 58,
                child: PageView.builder(
                  controller: _tickerCtrl,
                  itemBuilder: (context, index) {
                    final it = p.infoBarItems[index % p.infoBarItems.length];
                    return appCard(
                      context,
                      onTap: () {
                        final real = p.findBySlug(it.slug);
                        if (real != null) showMarketDetail(context, real);
                      },
                      child: Row(
                        children: [
                          CatIcon(it.category, size: 36),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(it.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 13)),
                          ),
                          Text(
                            fmtPrice(context, it.priceRial),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const SizedBox(width: 4),
                          Text(unitWord(s),
                              style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                          const SizedBox(width: 10),
                          if (s.showPct) ChangeChip(it.changePct, small: true),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
            // ---------- آمار سریع ----------
            if (p.summaryWidgets.isNotEmpty) ...[
              const SectionTitle('آمار سریع'),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.75,
                children: p.summaryWidgets.entries.take(6).map((e) {
                  final m = e.value;
                  final pct = (m['change_pct'] as num?)?.toDouble();
                  return appCard(
                    context,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          (m['title'] ?? '').toString(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          m['price'] != null
                              ? fmtPrice(context, (m['price'] as num).toDouble())
                              : (m['price_raw'] ?? '—').toString(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        if (s.showPct) ChangeChip(pct, small: true),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
            // ---------- شاخص‌های بازار ----------
            if (p.tableHeaderSummary.isNotEmpty) ...[
              const SectionTitle('شاخص‌های بازار'),
              SizedBox(
                height: 132,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: p.tableHeaderSummary.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, i) {
                    final m = p.tableHeaderSummary.values.elementAt(i);
                    return SizedBox(
                      width: 210,
                      child: appCard(
                        context,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (m['title'] ?? '').toString(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              m['price'] != null
                                  ? fmtPrice(context, (m['price'] as num).toDouble())
                                  : (m['price_raw'] ?? '—').toString(),
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 17,
                                color: scheme.primary,
                              ),
                            ),
                            const Spacer(),
                            Row(
                              children: [
                                if (m['daily_change'] != null)
                                  Flexible(
                                    child: Text(
                                      'تغییر روزانه: ${m['daily_change']}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          fontSize: 10, color: Colors.grey.shade600),
                                    ),
                                  ),
                              ],
                            ),
                            if (m['date'] != null && m['date'].toString().isNotEmpty)
                              Text(
                                m['date'].toString(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 9, color: Colors.grey.shade500),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
            // ---------- علاقه‌مندی‌ها ----------
            if (favItems.isNotEmpty) ...[
              const SectionTitle('علاقه‌مندی‌ها'),
              for (final f in favItems) MarketTile(item: f),
            ],
            // ---------- پرتلاطم‌ها ----------
            if (p.topMovers.isNotEmpty) ...[
              const SectionTitle('پرتلاطم‌ترین‌های امروز'),
              appCard(
                context,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: p.topMovers.map((m) {
                    final c = changeColor(m.changePct);
                    return InkWell(
                      borderRadius: BorderRadius.circular(99),
                      onTap: () => showMarketDetail(context, m),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: c.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(color: c.withOpacity(0.25)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(m.title,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            const SizedBox(width: 6),
                            ChangeChip(m.changePct, small: true),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
            // ---------- اخبار ----------
            if (p.headerNews.isNotEmpty) ...[
              const SectionTitle('آخرین اخبار'),
              for (final n in p.headerNews.take(3))
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: appCard(
                    context,
                    onTap: () => openUrl(n['url']?.toString() ?? 'https://www.tgju.org/'),
                    child: Row(
                      children: [
                        Container(
                          width: 38, height: 38,
                          decoration: BoxDecoration(
                            color: scheme.primary.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.article_rounded, color: scheme.primary, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                n['title']?.toString() ?? '',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${n['category'] ?? ''} • ${n['created_at'] ?? ''}',
                                style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_left_rounded, color: Colors.grey.shade400),
                      ],
                    ),
                  ),
                ),
            ],
            const SizedBox(height: 12),
            Center(
              child: TextButton.icon(
                onPressed: () => openUrl('https://www.tgju.org/'),
                icon: const Icon(Icons.open_in_new_rounded, size: 15),
                label: const Text('منبع: شبکه اطلاع‌رسانی طلا و ارز'),
              ),
            ),
          ],
        ),
      );
    });
  }
}

// ============================================================
// صفحه بازارها (طلا / سکه / ارز / رمزارز)
// ============================================================
class MarketsScreen extends StatefulWidget {
  final String category;
  const MarketsScreen({super.key, required this.category});
  @override
  State<MarketsScreen> createState() => _MarketsScreenState();
}

class _MarketsScreenState extends State<MarketsScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppSettings>();
    final p = context.watch<MarketDataProvider>();
    final meta = kTabMeta[widget.category] ?? kTabMeta['currency']!;

    return dataGate(context, () {
      final list = p.filtered(widget.category, _query);
      return RefreshIndicator(
        onRefresh: () => p.refresh(force: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 130),
          children: [
            Row(
              children: [
                CatIcon(widget.category, size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('بازار ${meta.$1}',
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
                      Text(
                        s.persianDigits ? toFa('${list.length} مورد') : '${list.length} مورد',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: p.loading ? null : () => p.refresh(force: true),
                  icon: p.loading
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'جستجو در ${meta.$1}...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _query = '');
                        })
                    : null,
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(s.cardRadius),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 14),
            if (list.isEmpty)
              const EmptyState(Icons.search_off_rounded, 'موردی یافت نشد.')
            else
              for (final item in list) MarketTile(item: item),
            // ---------- صرافی‌های رمزارز ----------
            if (widget.category == 'crypto' && p.cryptoExchanges.isNotEmpty) ...[
              const SectionTitle('صرافی‌های رمزارز'),
              for (final ex in p.cryptoExchanges)
                Padding(
                  padding: EdgeInsets.only(bottom: s.compact ? 6 : 10),
                  child: appCard(
                    context,
                    onTap: ex['url'] != null ? () => openUrl(ex['url'].toString()) : null,
                    child: Row(
                      children: [
                        Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFF8E24AA).withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.storefront_rounded,
                              color: Color(0xFF8E24AA), size: 22),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            ex['exchange']?.toString() ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('خرید: ${fmtPrice(context, (ex['buy'] as num?)?.toDouble())}',
                                style: const TextStyle(fontSize: 12, color: Color(0xFF16A34A))),
                            Text('فروش: ${fmtPrice(context, (ex['sell'] as num?)?.toDouble())}',
                                style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626))),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ],
        ),
      );
    });
  }
}

// ============================================================
// صفحه نمودارها
// ============================================================
class ChartsScreen extends StatefulWidget {
  const ChartsScreen({super.key});
  @override
  State<ChartsScreen> createState() => _ChartsScreenState();
}

class _ChartsScreenState extends State<ChartsScreen> {
  String? _selected;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppSettings>();
    final p = context.watch<MarketDataProvider>();
    final scheme = Theme.of(context).colorScheme;

    return dataGate(context, () {
      final selectable = [...p.items];
      selectable.sort((a, b) {
        final af = s.favorites.contains(a.slug) ? 0 : 1;
        final bf = s.favorites.contains(b.slug) ? 0 : 1;
        if (af != bf) return af.compareTo(bf);
        return (b.changePct?.abs() ?? 0).compareTo(a.changePct?.abs() ?? 0);
      });
      final options = selectable.take(40).toList();
      _selected ??= options.isNotEmpty ? options.first.slug : null;
      if (_selected != null && !options.any((o) => o.slug == _selected)) {
        _selected = options.isNotEmpty ? options.first.slug : null;
      }
      final selected = _selected == null ? null : p.findBySlug(_selected!);
      final prices = selected?.history
              .map((h) => (h['price'] as num?)?.toDouble())
              .whereType<double>()
              .toList() ??
          [];
      final movers = p.topMovers;
      final maxAbs = movers.isEmpty
          ? 1.0
          : movers.map((m) => m.changePct!.abs()).reduce(math.max);

      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 130),
        children: [
          const Text('نمودارها و شاخص‌ها',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
          const SizedBox(height: 14),
          appCard(
            context,
            child: DropdownButtonFormField<String>(
              value: _selected,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'انتخاب بازار برای نمایش روند امروز',
                prefixIcon: Icon(Icons.query_stats_rounded),
                border: OutlineInputBorder(),
              ),
              items: [
                for (final o in options)
                  DropdownMenuItem(value: o.slug, child: Text(o.title, overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (v) => setState(() => _selected = v),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 250,
            child: appCard(
              context,
              child: prices.length >= 2
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                selected?.title ?? '',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            ChangeChip(selected?.changePct),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Expanded(
                          child: _HistoryChart(
                            prices: prices,
                            color: changeColor(selected?.changePct),
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'اولین: ${fmtPrice(context, selected?.history.isNotEmpty == true ? (selected!.history.first['price'] as num?)?.toDouble() : null)}',
                              style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                            ),
                            Text(
                              'آخرین: ${fmtPrice(context, selected?.priceRial)}',
                              style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ],
                    )
                  : const EmptyState(
                      Icons.show_chart_rounded,
                      'داده تاریخچه امروز برای این بازار هنوز ثبت نشده است.',
                    ),
            ),
          ),
          // ---------- بیشترین تغییر ----------
          if (movers.isNotEmpty) ...[
            const SectionTitle('بیشترین تغییر امروز'),
            appCard(
              context,
              child: Column(
                children: [
                  for (final m in movers)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => showMarketDetail(context, m),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 95,
                              child: Text(m.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12)),
                            ),
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(99),
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: Container(
                                    height: 9,
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          changeColor(m.changePct).withOpacity(0.25),
                                          changeColor(m.changePct),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(99),
                                    ),
                                    child: FractionallySizedBox(
                                      alignment: Alignment.centerRight,
                                      widthFactor: (m.changePct!.abs() / maxAbs).clamp(0.06, 1.0),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: changeColor(m.changePct),
                                          borderRadius: BorderRadius.circular(99),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(width: 58, child: ChangeChip(m.changePct, small: true)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
          // ---------- شاخص‌ها ----------
          if (p.indexTabsSummary.isNotEmpty) ...[
            const SectionTitle('شاخص‌های منتخب'),
            for (final e in p.indexTabsSummary.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: appCard(
                  context,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.value['title']?.toString() ?? '',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      if ((e.value['raw_date'] ?? '').toString().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            e.value['raw_date'].toString(),
                            style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                          ),
                        ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: (e.value['items'] as Map?)
                                ?.entries
                                .map((it) => Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: scheme.primary.withOpacity(0.07),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        '${it.key}: ${it.value}',
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                    ))
                                .toList() ??
                            [],
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ],
      );
    });
  }
}

// ============================================================
// صفحه اخبار / تحلیل‌ها / تقویم
// ============================================================
class NewsScreen extends StatelessWidget {
  const NewsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return dataGate(context, () {
      final scheme = Theme.of(context).colorScheme;
      return DefaultTabController(
        length: 3,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Align(
                alignment: Alignment.centerRight,
                child: const Text('اخبار و تحلیل‌ها',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
              ),
            ),
            TabBar(
              isScrollable: true,
              labelStyle: const TextStyle(fontFamily: 'Vazir', fontSize: 13),
              indicatorColor: scheme.primary,
              labelColor: scheme.primary,
              unselectedLabelColor: Colors.grey,
              tabs: const [
                Tab(text: 'اخبار'),
                Tab(text: 'تحلیل‌ها'),
                Tab(text: 'تقویم اقتصادی'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _NewsList(),
                  _TechnicalsList(),
                  _CalendarList(),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }
}

class _NewsList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final p = context.watch<MarketDataProvider>();
    final s = context.watch<AppSettings>();
    if (p.headerNews.isEmpty) {
      return const EmptyState(Icons.newspaper_rounded, 'خبری یافت نشد.');
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 130),
      itemCount: p.headerNews.length,
      itemBuilder: (context, i) {
        final n = p.headerNews[i];
        return Padding(
          padding: EdgeInsets.only(bottom: s.compact ? 6 : 10),
          child: appCard(
            context,
            onTap: () => openUrl(n['url']?.toString() ?? 'https://www.tgju.org/'),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        n['title']?.toString() ?? '',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(
                              n['category']?.toString() ?? '',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: Theme.of(context).colorScheme.primary),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            n['created_at']?.toString() ?? '',
                            style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_left_rounded, color: Colors.grey.shade400),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TechnicalsList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final p = context.watch<MarketDataProvider>();
    final s = context.watch<AppSettings>();
    if (p.technicals.isEmpty) {
      return const EmptyState(Icons.analytics_rounded, 'تحلیلی یافت نشد.');
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 130),
      itemCount: p.technicals.length,
      itemBuilder: (context, i) {
        final t = p.technicals[i];
        final img = t['image']?.toString();
        return Padding(
          padding: EdgeInsets.only(bottom: s.compact ? 6 : 12),
          child: appCard(
            context,
            onTap: t['url'] != null ? () => openUrl(t['url'].toString()) : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (s.showImages && img != null && img.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.network(
                      img,
                      height: 140,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                if (s.showImages && img != null && img.isNotEmpty) const SizedBox(height: 10),
                Text(
                  t['title']?.toString() ?? '',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.person_rounded, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(t['analyst']?.toString() ?? '',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                    const SizedBox(width: 12),
                    const Icon(Icons.schedule_rounded, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(t['time']?.toString() ?? '',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                  ],
                ),
                if ((t['content'] ?? '').toString().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    t['content'].toString(),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700, height: 1.7),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CalendarList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final p = context.watch<MarketDataProvider>();
    final s = context.watch<AppSettings>();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 130),
      children: [
        if (p.calendar.isEmpty)
          const EmptyState(Icons.event_busy_rounded, 'رویدادی یافت نشد.')
        else
          for (final ev in p.calendar)
            Padding(
              padding: EdgeInsets.only(bottom: s.compact ? 6 : 10),
              child: appCard(
                context,
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Text(
                            s.persianDigits ? toFa(ev['time']?.toString() ?? '--:--') : (ev['time']?.toString() ?? '--:--'),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          if ((ev['flag'] ?? '').toString().isNotEmpty)
                            Text(ev['flag'].toString().toUpperCase(),
                                style: const TextStyle(fontSize: 8, color: Colors.grey)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ev['title']?.toString() ?? '',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            ev['country']?.toString() ?? '',
                            style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('قبلی: ${ev['previous'] ?? '—'}',
                            style: const TextStyle(fontSize: 10)),
                        Text('پیش‌بینی: ${ev['forecast'] ?? '—'}',
                            style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        // ---------- نقشه جهانی ----------
        if (p.worldMap.isNotEmpty) ...[
          const SectionTitle('شاخص‌های جهانی'),
          appCard(
            context,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: p.worldMap
                  .map((w) => Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.secondary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(w['title']?.toString() ?? '',
                            style: const TextStyle(fontSize: 11)),
                      ))
                  .toList(),
            ),
          ),
        ],
      ],
    );
  }
}

// ============================================================
// صفحه تنظیمات
// ============================================================
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Widget _section(String title, IconData icon, List<Widget> children) {
    return Builder(builder: (context) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
            child: Row(
              children: [
                Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            ),
          ),
          appCard(context, padding: const EdgeInsets.symmetric(vertical: 6), child: Column(children: children)),
        ],
      );
    });
  }

  Widget _switchTile(BuildContext context,
      {required String title,
      String? subtitle,
      required IconData icon,
      required bool value,
      required ValueChanged<bool> onChanged}) {
    return SwitchListTile(
      secondary: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(title, style: const TextStyle(fontSize: 13)),
      subtitle: subtitle != null ? Text(subtitle, style: const TextStyle(fontSize: 11)) : null,
      value: value,
      onChanged: onChanged,
    );
  }

  Widget _sliderTile(BuildContext context,
      {required String title,
      required IconData icon,
      required double value,
      required double min,
      required double max,
      int? divisions,
      String? label,
      required ValueChanged<double> onChanged}) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(title, style: const TextStyle(fontSize: 13)),
      subtitle: Slider(
        value: value,
        min: min,
        max: max,
        divisions: divisions,
        label: label ?? value.toStringAsFixed(0),
        onChanged: onChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppSettings>();
    final p = context.read<MarketDataProvider>();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
      children: [
        const Text('تنظیمات',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
        const SizedBox(height: 4),
        Text(
          'همه‌چیز را دقیقاً مطابق سلیقه خود شخصی‌سازی کنید.',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),

        // ---------- ظاهر ----------
        _section('ظاهر برنامه', Icons.palette_rounded, [
          ListTile(
            leading: Icon(Icons.brightness_6_rounded,
                color: Theme.of(context).colorScheme.primary),
            title: const Text('حالت نمایش', style: TextStyle(fontSize: 13)),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 0, label: Text('سیستم')),
                  ButtonSegment(value: 1, label: Text('روشن')),
                  ButtonSegment(value: 2, label: Text('تاریک')),
                ],
                selected: {s.themeMode},
                showSelectedIcon: false,
                onSelectionChanged: (v) => s.themeMode = v.first,
              ),
            ),
          ),
          ListTile(
            leading: Icon(Icons.color_lens_rounded,
                color: Theme.of(context).colorScheme.primary),
            title: const Text('رنگ اصلی برنامه', style: TextStyle(fontSize: 13)),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: List.generate(kPalette.length, (i) {
                  final selected = s.seedIndex == i;
                  return GestureDetector(
                    onTap: () => s.seedIndex = i,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: kPalette[i],
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected ? Theme.of(context).colorScheme.onSurface : Colors.transparent,
                          width: 2,
                        ),
                        boxShadow: selected
                            ? [BoxShadow(color: kPalette[i].withOpacity(0.5), blurRadius: 8)]
                            : null,
                      ),
                      child: selected
                          ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
                          : null,
                    ),
                  );
                }),
              ),
            ),
          ),
          _sliderTile(context,
              title: 'اندازه متن',
              icon: Icons.text_fields_rounded,
              value: s.fontScale,
              min: 0.85,
              max: 1.3,
              divisions: 9,
              label: '${(s.fontScale * 100).round()}٪',
              onChanged: (v) => s.fontScale = v),
          _sliderTile(context,
              title: 'گردی گوشه کارت‌ها',
              icon: Icons.rounded_corner_rounded,
              value: s.cardRadius,
              min: 8,
              max: 30,
              divisions: 22,
              onChanged: (v) => s.cardRadius = v),
          _switchTile(context,
              title: 'انیمیشن‌ها',
              subtitle: 'جلوه‌های حرکتی بین صفحات',
              icon: Icons.animation_rounded,
              value: s.animations,
              onChanged: (v) => s.animations = v),
          _switchTile(context,
              title: 'حالت فشرده',
              subtitle: 'کاهش فاصله‌ها برای نمایش بیشتر',
              icon: Icons.compress_rounded,
              value: s.compact,
              onChanged: (v) => s.compact = v),
          _switchTile(context,
              title: 'نمایش تصاویر تحلیل‌ها',
              icon: Icons.image_rounded,
              value: s.showImages,
              onChanged: (v) => s.showImages = v),
        ]),

        // ---------- نوار پایین ----------
        _section('نوار پایین شیشه‌ای', Icons.blur_on_rounded, [
          _switchTile(context,
              title: 'نمایش متن تب‌ها',
              icon: Icons.text_fields_rounded,
              value: s.navLabels,
              onChanged: (v) => s.navLabels = v),
          _sliderTile(context,
              title: 'اندازه آیکون‌ها',
              icon: Icons.crop_square_rounded,
              value: s.navIconSize,
              min: 20,
              max: 32,
              divisions: 12,
              onChanged: (v) => s.navIconSize = v),
          _sliderTile(context,
              title: 'عرض منو',
              icon: Icons.width_wide_rounded,
              value: s.navWidthPct,
              min: 55,
              max: 100,
              divisions: 9,
              label: '${s.navWidthPct.round()}٪',
              onChanged: (v) => s.navWidthPct = v),
          _sliderTile(context,
              title: 'فاصله از پایین صفحه',
              icon: Icons.vertical_align_bottom_rounded,
              value: s.navBottomPad,
              min: 8,
              max: 36,
              divisions: 14,
              onChanged: (v) => s.navBottomPad = v),
          ListTile(
            leading: Icon(Icons.colorize_rounded,
                color: Theme.of(context).colorScheme.primary),
            title: const Text('رنگ تب فعال', style: TextStyle(fontSize: 13)),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  GestureDetector(
                    onTap: () => s.navColorIdx = -1,
                    child: Container(
                      width: 34, height: 34,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: s.navColorIdx == -1
                              ? Theme.of(context).colorScheme.onSurface
                              : Colors.grey.shade400,
                          width: 2,
                        ),
                      ),
                      child: const Icon(Icons.auto_awesome_rounded, size: 16),
                    ),
                  ),
                  ...List.generate(kPalette.length, (i) {
                    final selected = s.navColorIdx == i;
                    return GestureDetector(
                      onTap: () => s.navColorIdx = i,
                      child: Container(
                        width: 34, height: 34,
                        decoration: BoxDecoration(
                          color: kPalette[i],
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selected
                                ? Theme.of(context).colorScheme.onSurface
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: selected
                            ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                            : null,
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ]),

        // ---------- تب‌ها ----------
        _section('چینش تب‌ها', Icons.tab_rounded, [
          const ListTile(
            dense: true,
            title: Text('حداکثر ۳ تب دلخواه علاوه بر «خانه» و «تنظیمات» انتخاب کنید.',
                style: TextStyle(fontSize: 11)),
          ),
          for (final id in ['gold', 'coin', 'currency', 'crypto', 'charts', 'news'])
            Builder(builder: (context) {
              final meta = kTabMeta[id]!;
              final opt = s.optionalTabs;
              final enabled = opt.contains(id);
              final idx = opt.indexOf(id);
              return ListTile(
                leading: Icon(meta.$2, color: meta.$3),
                title: Text(meta.$1, style: const TextStyle(fontSize: 13)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: enabled && idx > 0 ? () => s.moveTab(id, -1) : null,
                      icon: const Icon(Icons.arrow_upward_rounded, size: 18),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: enabled && idx < opt.length - 1 ? () => s.moveTab(id, 1) : null,
                      icon: const Icon(Icons.arrow_downward_rounded, size: 18),
                    ),
                    Switch(
                      value: enabled,
                      onChanged: (_) {
                        if (!enabled && opt.length >= 3) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('حداکثر ۳ تب دلخواه مجاز است.')),
                          );
                          return;
                        }
                        if (enabled && opt.length <= 1) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('حداقل یک تب باید فعال باشد.')),
                          );
                          return;
                        }
                        s.toggleTab(id);
                      },
                    ),
                  ],
                ),
              );
            }),
        ]),

        // ---------- نمایش قیمت‌ها ----------
        _section('نمایش قیمت‌ها', Icons.payments_rounded, [
          _switchTile(context,
              title: 'اعداد فارسی',
              subtitle: 'نمایش ارقام به صورت ۰ تا ۹',
              icon: Icons.translate_rounded,
              value: s.persianDigits,
              onChanged: (v) => s.persianDigits = v),
          ListTile(
            leading: Icon(Icons.monetization_on_rounded,
                color: Theme.of(context).colorScheme.primary),
            title: const Text('واحد نمایش قیمت', style: TextStyle(fontSize: 13)),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 1, label: Text('تومان')),
                  ButtonSegment(value: 0, label: Text('ریال')),
                ],
                selected: {s.priceUnit},
                showSelectedIcon: false,
                onSelectionChanged: (v) => s.priceUnit = v.first,
              ),
            ),
          ),
          _switchTile(context,
              title: 'نمایش درصد تغییر',
              icon: Icons.percent_rounded,
              value: s.showPct,
              onChanged: (v) => s.showPct = v),
          _switchTile(context,
              title: 'نمایش مقدار تغییر',
              icon: Icons.swap_vert_rounded,
              value: s.showChangeVal,
              onChanged: (v) => s.showChangeVal = v),
          _switchTile(context,
              title: 'نمایش کمترین و بیشترین',
              icon: Icons.candlestick_chart_rounded,
              value: s.showHighLow,
              onChanged: (v) => s.showHighLow = v),
          _switchTile(context,
              title: 'نمایش ساعت به‌روزرسانی',
              icon: Icons.schedule_rounded,
              value: s.showTime,
              onChanged: (v) => s.showTime = v),
          _switchTile(context,
              title: 'علاقه‌مندی‌ها در ابتدای فهرست',
              icon: Icons.star_rounded,
              value: s.favoritesFirst,
              onChanged: (v) => s.favoritesFirst = v),
          ListTile(
            leading: Icon(Icons.sort_rounded,
                color: Theme.of(context).colorScheme.primary),
            title: const Text('مرتب‌سازی فهرست‌ها', style: TextStyle(fontSize: 13)),
            subtitle: DropdownButtonFormField<int>(
              value: s.sortMode,
              items: const [
                DropdownMenuItem(value: 0, child: Text('پیش‌فرض سایت')),
                DropdownMenuItem(value: 1, child: Text('بیشترین قیمت')),
                DropdownMenuItem(value: 2, child: Text('کمترین قیمت')),
                DropdownMenuItem(value: 3, child: Text('بیشترین تغییر')),
                DropdownMenuItem(value: 4, child: Text('بر اساس نام')),
              ],
              onChanged: (v) => s.sortMode = v ?? 0,
            ),
          ),
        ]),

        // ---------- به‌روزرسانی ----------
        _section('دریافت اطلاعات', Icons.sync_rounded, [
          ListTile(
            leading: Icon(Icons.update_rounded,
                color: Theme.of(context).colorScheme.primary),
            title: const Text('به‌روزرسانی خودکار', style: TextStyle(fontSize: 13)),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 0, label: Text('خاموش')),
                  ButtonSegment(value: 1, label: Text('۱ دقیقه')),
                  ButtonSegment(value: 2, label: Text('۲ دقیقه')),
                  ButtonSegment(value: 5, label: Text('۵ دقیقه')),
                ],
                selected: {s.autoRefreshMin},
                showSelectedIcon: false,
                onSelectionChanged: (v) => s.autoRefreshMin = v.first,
              ),
            ),
          ),
          _switchTile(context,
              title: 'ذخیره کش برای مشاهده آفلاین',
              subtitle: 'کاهش درخواست‌های شبکه',
              icon: Icons.save_rounded,
              value: s.useCache,
              onChanged: (v) => s.useCache = v),
          ListTile(
            leading: Icon(Icons.delete_sweep_rounded,
                color: Theme.of(context).colorScheme.primary),
            title: const Text('پاک کردن کش', style: TextStyle(fontSize: 13)),
            subtitle: Text(
              p.lastUpdated == null
                  ? 'هنوز داده‌ای ذخیره نشده'
                  : 'آخرین به‌روزرسانی: ${fmtClock(p.lastUpdated!, s.persianDigits)}',
              style: const TextStyle(fontSize: 11),
            ),
            onTap: () async {
              await p.clearCache();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('کش برنامه پاک شد.')),
              );
            },
          ),
        ]),

        // ---------- علاقه‌مندی‌ها و هشدارها ----------
        _section('علاقه‌مندی‌ها و هشدارها', Icons.notifications_rounded, [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('علاقه‌مندی‌ها',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 8),
                if (s.favorites.isEmpty)
                  Text('موردی ثبت نشده است. با لمس ستاره روی هر بازار، آن را اینجا اضافه کنید.',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600))
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: s.favorites.map((slug) {
                      final item = p.findBySlug(slug);
                      return InputChip(
                        label: Text(item?.title ?? slug, style: const TextStyle(fontSize: 11)),
                        onDeleted: () => s.toggleFavorite(slug),
                      );
                    }).toList(),
                  ),
                const SizedBox(height: 16),
                const Text('هشدارهای قیمت',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 8),
                if (s.alerts.isEmpty)
                  Text('هشداری ثبت نشده است. از صفحه جزئیات هر بازار هشدار تنظیم کنید.',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600))
                else
                  for (final e in s.alerts.entries)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          const Icon(Icons.notifications_active_rounded,
                              size: 16, color: Colors.amber),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${p.findBySlug(e.key)?.title ?? e.key}: ${e.value['dir'] == 'above' ? 'صعود به بالای' : 'نزول به پایین'} '
                              '${formatNumber((e.value['v'] as num?)?.toDouble(), fa: s.persianDigits)} ${unitWord(s)}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.close_rounded, size: 18),
                            onPressed: () => s.removeAlert(e.key),
                          ),
                        ],
                      ),
                    ),
              ],
            ),
          ),
        ]),

        // ---------- درباره ----------
        _section('درباره برنامه', Icons.info_rounded, [
          const ListTile(
            leading: Icon(Icons.workspace_premium_rounded, color: Colors.amber),
            title: Text('نبض بازار — نسخه ۱٫۰', style: TextStyle(fontSize: 13)),
            subtitle: Text(
              'منبع داده: شبکه اطلاع‌رسانی طلا و ارز (tgju.org)\nساخته‌شده با فلاتر و فونت وزیر',
              style: TextStyle(fontSize: 11, height: 1.8),
            ),
            isThreeLine: true,
          ),
          ListTile(
            leading: const Icon(Icons.open_in_browser_rounded, color: Colors.blue),
            title: const Text('مشاهده سایت منبع', style: TextStyle(fontSize: 13)),
            onTap: () => openUrl('https://www.tgju.org/'),
          ),
        ]),

        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.redAccent),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(s.cardRadius)),
            ),
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('بازنشانی تنظیمات'),
                  content: const Text('تمام تنظیمات به حالت پیش‌فرض بازمی‌گردد. ادامه می‌دهید؟'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('انصراف'),
                    ),
                    FilledButton(
                      onPressed: () {
                        s.reset();
                        Navigator.pop(ctx);
                      },
                      child: const Text('بازنشانی'),
                    ),
                  ],
                ),
              );
            },
            icon: const Icon(Icons.restore_rounded),
            label: const Text('بازنشانی همه تنظیمات'),
          ),
        ),
      ],
    );
  }
}