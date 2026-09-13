// ============================================================================
// 🎴 PASKAR v2.1 — کلاینت پیشرفته بازی‌های پاسور ایرانی
// چهاربرگ (یازده) | هفت خبیث | شلم | حکم
// ============================================================================
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:confetti/confetti.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vibration/vibration.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

// ============================================================================
// 1) ثوابت و کمکی‌ها
// ============================================================================
const String kFont = 'Vazir';
const String kAppVersion = '2.1.0';

class PColors {
  static const bg1 = Color(0xFF0B1220);
  static const bg2 = Color(0xFF101B33);
  static const panel = Color(0xFF16233E);
  static const panel2 = Color(0xFF1E2F55);
  static const gold = Color(0xFFF2C14E);
  static const goldDark = Color(0xFFC99A2E);
  static const green = Color(0xFF27C485);
  static const red = Color(0xFFFF5C6C);
  static const blue = Color(0xFF4FA3FF);
  static const purple = Color(0xFFA78BFA);
  static const teal = Color(0xFF2EC4B6);
  static const felt1 = Color(0xFF116A45);
  static const felt2 = Color(0xFF0A3D28);
  static const text = Color(0xFFEDF2FA);
  static const sub = Color(0xFF93A3C0);

  // Light theme colors
  static const lBg1 = Color(0xFFF5F7FB);
  static const lBg2 = Color(0xFFEEF2F9);
  static const lPanel = Color(0xFFFFFFFF);
  static const lText = Color(0xFF1A2340);
  static const lSub = Color(0xFF5A6B8A);
}

class SuitInfo {
  final String symbol, fa;
  final Color color;
  const SuitInfo(this.symbol, this.fa, this.color);
}

const Map<String, SuitInfo> kSuits = {
  'hearts': SuitInfo('♥', 'دل', Color(0xFFFF5C7A)),
  'diamonds': SuitInfo('♦', 'خشت', Color(0xFFFFB84D)),
  'clubs': SuitInfo('♣', 'گشنیز', Color(0xFF58C7F3)),
  'spades': SuitInfo('♠', 'پیک', Color(0xFFE8EEF9)),
};

const Map<String, int> kRankOrder = {
  '2': 2, '3': 3, '4': 4, '5': 5, '6': 6, '7': 7, '8': 8, '9': 9,
  '10': 10, 'J': 11, 'Q': 12, 'K': 13, 'A': 14,
};
const Map<String, int> kSuitOrder = {'spades': 0, 'hearts': 1, 'clubs': 2, 'diamonds': 3};

class GameMeta {
  final String type, name, icon, desc;
  final int minPlayers, maxPlayers;
  final Color color;
  final List<String> rules;
  const GameMeta({
    required this.type, required this.name, required this.icon, required this.desc,
    required this.minPlayers, required this.maxPlayers, required this.color,
    required this.rules,
  });
  static const Map<String, GameMeta> all = {
    'chahar_barg': GameMeta(
      type: 'chahar_barg', name: 'چهاربرگ', icon: '🎯',
      desc: 'یازده‌برگ؛ بگیر و ببر!',
      minPlayers: 2, maxPlayers: 4, color: PColors.teal,
      rules: [
        '🎯 هر بازیکن ۴ کارت می‌گیرد و ۴ کارت روی میز می‌رود',
        '🃏 سرباز (J) همه کارت‌های غیر از شاه و بی‌بی را جمع می‌کند',
        '👑 شاه فقط شاه، بی‌بی فقط بی‌بی را می‌گیرد',
        '🔢 سایر کارت‌ها باید مجموعشان ۱۱ شود (مثلاً ۷+۴)',
        '✨ آخرین کسی که گرفته، کارت‌های باقیمانده میز را می‌برد',
        '🏆 کسی که بیشترین کارت را جمع کرده برنده است',
      ],
    ),
    'haft_khabis': GameMeta(
      type: 'haft_khabis', name: 'هفت خبیث', icon: '🎴',
      desc: 'اونو ایرانی با کارت‌های خبیث',
      minPlayers: 2, maxPlayers: 6, color: PColors.purple,
      rules: [
        '🎴 هر بازیکن ۷ کارت می‌گیرد',
        '🎲 باید کارتی بازی کنی که با کارت رویی هم‌خال یا هم‌عدد باشد',
        '7️⃣ هفت: نفر بعدی ۲ کارت می‌کشد (مگر خودش هفت بازی کند)',
        '2️⃣ دو: نفر بعدی ۲ کارت می‌کشد',
        '8️⃣ هشت: نوبت نفر بعدی می‌پرد',
        '🅰 تک: جهت بازی عوض می‌شود + یک نفر می‌پرد',
        '🔟 ده: می‌توانی هر خالی را اعلام کنی',
        '🏆 اولین کسی که کارت‌هایش تمام شود برنده است',
      ],
    ),
    'shelem': GameMeta(
      type: 'shelem', name: 'شلم', icon: '💎',
      desc: 'مزایده و حکم‌بازی تیمی',
      minPlayers: 4, maxPlayers: 4, color: PColors.blue,
      rules: [
        '💎 بازی تیمی ۴ نفره (۲ تیم)',
        '💰 فاز مزایده: پیشنهاد ۱۰۰ تا ۱۶۵ امتیاز',
        '👑 بالاترین پیشنهاددهنده حاکم می‌شود و حکم را انتخاب می‌کند',
        '🎯 امتیاز کارت‌ها: آس=۱۰، ده=۱۰، پنج=۵',
        '⚖ تیم حاکم باید حداقل به اندازه پیشنهادش امتیاز بگیرد',
        '🏆 اولین تیمی که به امتیاز هدف برسد برنده است',
      ],
    ),
    'hokm': GameMeta(
      type: 'hokm', name: 'حکم', icon: '👑',
      desc: 'کلاسیک تیمی ایرانی',
      minPlayers: 4, maxPlayers: 4, color: PColors.gold,
      rules: [
        '👑 بازی تیمی ۴ نفره',
        '🎴 هر بازیکن ۱۳ کارت می‌گیرد',
        '♠ نفر اول حاکم است و حکم را انتخاب می‌کند',
        '🎯 باید از خال شروع‌کننده بازی کنی (اگر داری)',
        '🏆 هر دست ۴ کارتی، یک «تریک» است',
        '🎖 تیمی که ۷ تریک بگیرد برنده بازی است',
      ],
    ),
  };
  static GameMeta of(String? t) => all[t] ?? all['chahar_barg']!;
}

const List<String> kEmotes = ['😂', '😎', '😮', '😢', '😡', '👍', '👏', '🔥', '🎉', '❤️', '💀', '🤝'];
const List<String> kAvatars = [
  '🙂', '😎', '🤩', '🥳', '😇', '🤠', '👻', '🤖', '👽', '🐱', '🦊', '🐼',
  '🦁', '🐯', '🐸', '🦄', '🐲', '🦅', '🌟', '🔥', '💎', '🎩', '🃏', '♠️',
  '♥️', '🎯', '🏆', '👑', '🚀', '🌙', '⚡', '🍀', '🎲', '🧠', '🗿', '🫠',
];

const List<Map<String, dynamic>> kDailyRewards = [
  {'day': 1, 'icon': '💰', 'title': '۱۰ سکه', 'desc': 'خوش‌آمد'},
  {'day': 2, 'icon': '🎁', 'title': 'جعبه شانس', 'desc': 'روز دوم'},
  {'day': 3, 'icon': '💎', 'title': '۱ جم', 'desc': 'روز سوم'},
  {'day': 4, 'icon': '🏆', 'title': 'نشان برنز', 'desc': 'روز چهارم'},
  {'day': 5, 'icon': '💰', 'title': '۵۰ سکه', 'desc': 'روز پنجم'},
  {'day': 6, 'icon': '🎭', 'title': 'آواتار خاص', 'desc': 'روز ششم'},
  {'day': 7, 'icon': '👑', 'title': 'تاج طلایی', 'desc': 'هفته اول'},
];

// ---- JSON helpers ----
String _s(dynamic v, [String d = '']) => v == null ? d : v.toString();
int _i(dynamic v, [int d = 0]) => v is int ? v : (v is num ? v.toInt() : (int.tryParse('$v') ?? d));
double _df(dynamic v, [double d = 0]) => v is num ? v.toDouble() : (double.tryParse('$v') ?? d);
bool _b(dynamic v, [bool d = false]) => v is bool ? v : d;
List _l(dynamic v) => v is List ? v : const [];
Map _m(dynamic v) => v is Map ? v : const {};

dynamic _gf(Map? m, String k) {
  if (m == null) return null;
  if (m.containsKey(k)) return m[k];
  if (m.containsKey('$k ')) return m['$k '];
  if (m.containsKey(' $k')) return m[' $k'];
  return null;
}

const List<String> _faDigits = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
String fa(dynamic v) =>
    '$v'.replaceAllMapped(RegExp(r'[0-9]'), (m) => _faDigits[int.parse(m.group(0)!)]);

String timeAgo(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  try {
    final dt = DateTime.parse(iso);
    final d = DateTime.now().toUtc().difference(dt);
    if (d.inMinutes < 1) return 'همین الان';
    if (d.inMinutes < 60) return '${fa(d.inMinutes)} دقیقه پیش';
    if (d.inHours < 24) return '${fa(d.inHours)} ساعت پیش';
    return '${fa(d.inDays)} روز پیش';
  } catch (_) {
    return '';
  }
}

final GlobalKey<ScaffoldMessengerState> rootMessenger = GlobalKey<ScaffoldMessengerState>();

void toast(String msg, {Color? color, int seconds = 3}) {
  rootMessenger.currentState?.hideCurrentSnackBar();
  rootMessenger.currentState?.showSnackBar(SnackBar(
    content: Text(msg, style: const TextStyle(fontFamily: kFont, fontSize: 13)),
    backgroundColor: color ?? PColors.panel2,
    behavior: SnackBarBehavior.floating,
    margin: const EdgeInsets.all(12),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    duration: Duration(seconds: seconds),
  ));
}

Future<bool> confirmDialog(BuildContext context, String title, String msg,
    {String ok = 'بله', String cancel = 'انصراف'}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title, style: const TextStyle(fontFamily: kFont, fontSize: 16)),
      content: Text(msg, style: const TextStyle(fontFamily: kFont, fontSize: 13, color: PColors.sub)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: Text(cancel)),
        TextButton(
          onPressed: () => Navigator.pop(c, true),
          child: Text(ok, style: const TextStyle(color: PColors.gold, fontWeight: FontWeight.bold)),
        ),
      ],
    ),
  );
  return r ?? false;
}

Future<String?> askTextDialog(BuildContext context, String title, String hint,
    {bool obscure = false, String? initial}) async {
  final ctrl = TextEditingController(text: initial ?? '');
  final r = await showDialog<String>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title, style: const TextStyle(fontFamily: kFont, fontSize: 16)),
      content: TextField(
        controller: ctrl,
        obscureText: obscure,
        autofocus: true,
        style: const TextStyle(fontFamily: kFont),
        decoration: InputDecoration(hintText: hint, hintTextDirection: ui.TextDirection.rtl),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('انصراف')),
        TextButton(
          onPressed: () => Navigator.pop(c, ctrl.text.trim()),
          child: const Text('تأیید', style: TextStyle(color: PColors.gold)),
        ),
      ],
    ),
  );
  return (r == null || r.isEmpty) ? null : r;
}

void showSheet(BuildContext context, Widget child, {bool dismissible = true}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    isDismissible: dismissible,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Container(
      decoration: const BoxDecoration(
        color: PColors.panel,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      padding: EdgeInsets.fromLTRB(18, 10, 18, 18 + MediaQuery.of(ctx).viewInsets.bottom),
      child: child,
    ),
  );
}

// ============================================================================
// 2) مدل‌ها
// ============================================================================
class UserModel {
  final String username, avatar, bio;
  final bool online;
  final int friendsCount;
  final Map stats;
  final List achievements;
  final String? createdAt, lastSeen;
  UserModel({
    required this.username, required this.avatar, required this.bio, required this.online,
    required this.friendsCount, required this.stats, required this.achievements,
    this.createdAt, this.lastSeen,
  });
  factory UserModel.from(Map m) => UserModel(
        username: _s(_gf(m, 'username')),
        avatar: _s(_gf(m, 'avatar'), '🙂'),
        bio: _s(_gf(m, 'bio')),
        online: _b(_gf(m, 'online')),
        friendsCount: _i(_gf(m, 'friends_count')),
        stats: _m(_gf(m, 'stats')),
        achievements: _l(_gf(m, 'achievements')),
        createdAt: _gf(m, 'created_at')?.toString(),
        lastSeen: _gf(m, 'last_seen')?.toString(),
      );
  int get wins => _i(_gf(stats, 'wins'));
  int get played => _i(_gf(stats, 'games_played'));
  int get losses => _i(_gf(stats, 'losses'));
  double get winRate => played == 0 ? 0 : wins / played;
}

// ============================================================================
// 3) سرویس API
// ============================================================================
class ApiError implements Exception {
  final String message;
  final int? code;
  ApiError(this.message, [this.code]);
  @override
  String toString() => message;
}

class ApiService {
  ApiService(this.prefs);
  final SharedPreferences prefs;

  static const defaultApiKey = 'default-secret-change-me';
  static const baseUrlSource =
      'https://raw.githubusercontent.com/sksjjsiii/MyFiles/main/url.txt';

  String baseUrl = '';
  String apiKey = defaultApiKey;
  String? session;
  String? username;

  Future<bool> fetchBaseUrl({bool force = false}) async {
    if (!force) {
      final c = prefs.getString('base_url');
      if (c != null && c.isNotEmpty) baseUrl = c;
    }
    try {
      final r = await http.get(Uri.parse(baseUrlSource)).timeout(const Duration(seconds: 12));
      if (r.statusCode == 200) {
        var u = r.body.trim().split('\n').first.trim();
        if (u.isNotEmpty) {
          if (!u.startsWith('http')) u = 'https://$u';
          baseUrl = u.replaceAll(RegExp(r'/+$'), '');
          await prefs.setString('base_url', baseUrl);
          return true;
        }
      }
    } catch (e) {
      debugPrint('fetchBaseUrl failed: $e');
    }
    return baseUrl.isNotEmpty;
  }

  Future<void> _maybeRefetch() async {
    try {
      await fetchBaseUrl(force: true);
    } catch (_) {}
  }

  Map<String, String> _headers({bool auth = true}) {
    final h = <String, String>{'X-API-Key': apiKey};
    if (auth && session != null) h['X-Session'] = session!;
    return h;
  }

  String _extractError(Map? data, int code) {
    if (data != null) {
      final d = data['detail'];
      if (d is String && d.isNotEmpty) return d;
      if (d is List && d.isNotEmpty) {
        final f = d.first;
        if (f is Map && f['msg'] != null) return _s(f['msg']);
      }
    }
    switch (code) {
      case 401: return 'نشست معتبر نیست؛ دوباره وارد شوید';
      case 403: return 'API Key نامعتبر است. از تنظیمات اصلاح کنید';
      case 404: return 'یافت نشد';
      case 400: return 'درخواست نامعتبر است';
    }
    return 'خطای سرور ($code)';
  }

  Future<Map<String, dynamic>> _req(String method, String path,
      {Map<String, dynamic>? body, Map<String, String>? query, bool auth = true, bool retry = true}) async {
    if (baseUrl.isEmpty) throw ApiError('آدرس سرور تنظیم نشده است');
    Uri uri = Uri.parse('$baseUrl$path');
    if (query != null && query.isNotEmpty) uri = uri.replace(queryParameters: query);
    final h = _headers(auth: auth);
    if (body != null) h['Content-Type'] = 'application/json; charset=utf-8';
    http.Response r;
    try {
      final req = http.Request(method, uri);
      req.headers.addAll(h);
      if (body != null) req.body = jsonEncode(body);
      final streamed = await req.send().timeout(const Duration(seconds: 20));
      r = await http.Response.fromStream(streamed);
    } on TimeoutException {
      if (retry) {
        await _maybeRefetch();
        return _req(method, path, body: body, query: query, auth: auth, retry: false);
      }
      throw ApiError('پاسخ سرور طول کشید؛ دوباره تلاش کن');
    } catch (e) {
      if (retry) {
        await _maybeRefetch();
        return _req(method, path, body: body, query: query, auth: auth, retry: false);
      }
      throw ApiError('اتصال به سرور برقرار نشد: $e');
    }
    Map<String, dynamic>? data;
    try {
      data = r.body.isEmpty ? <String, dynamic>{} : Map<String, dynamic>.from(jsonDecode(r.body));
    } catch (_) {
      data = null;
    }
    if (r.statusCode >= 200 && r.statusCode < 300) return data ?? {};
    throw ApiError(_extractError(data, r.statusCode), r.statusCode);
  }

  // ---- Auth ----
  Future<Map<String, dynamic>> register(String u, String? p, String avatar, String bio) =>
      _req('POST', '/api/register', body: {
        'username': u,
        if (p != null && p.isNotEmpty) 'password': p,
        'avatar': avatar,
        'bio': bio,
      });
  Future<Map<String, dynamic>> login(String u, String? p) => _req('POST', '/api/login',
      body: {'username': u, if (p != null && p.isNotEmpty) 'password': p});
  Future<Map<String, dynamic>> logout() => _req('POST', '/api/logout');

  // ---- Users ----
  Future<Map<String, dynamic>> me() => _req('GET', '/api/users/me');
  Future<Map<String, dynamic>> userProfile(String u) => _req('GET', '/api/users/$u');
  Future<Map<String, dynamic>> users({String? q, int limit = 30}) =>
      _req('GET', '/api/users', query: {if (q != null && q.isNotEmpty) 'q': q, 'limit': '$limit'});
  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> body) =>
      _req('PATCH', '/api/users/me', body: body);

  // ---- Friends ----
  Future<Map<String, dynamic>> friends() => _req('GET', '/api/friends');
  Future<Map<String, dynamic>> friendRequest(String u) =>
      _req('POST', '/api/friends/request', body: {'username': u});
  Future<Map<String, dynamic>> friendAccept(String u) =>
      _req('POST', '/api/friends/accept', body: {'username': u});
  Future<Map<String, dynamic>> friendRemove(String u) => _req('DELETE', '/api/friends/$u');
  Future<Map<String, dynamic>> blockUser(String u) => _req('POST', '/api/friends/block/$u');

  // ---- Misc ----
  Future<Map<String, dynamic>> notifications() => _req('GET', '/api/notifications');
  Future<Map<String, dynamic>> markNotifsRead() => _req('POST', '/api/notifications/read');
  Future<Map<String, dynamic>> leaderboard({String? game, int limit = 30}) =>
      _req('GET', '/api/leaderboard', query: {if (game != null) 'game': game, 'limit': '$limit'});
  Future<Map<String, dynamic>> achievements() => _req('GET', '/api/achievements');
  Future<Map<String, dynamic>> health() => _req('GET', '/health', auth: false, retry: false);

  // ---- Rooms ----
  Future<Map<String, dynamic>> rooms({String? game}) =>
      _req('GET', '/api/rooms', query: {if (game != null) 'game': game});
  Future<Map<String, dynamic>> createRoom(Map<String, dynamic> body) =>
      _req('POST', '/api/rooms', body: body);
  Future<Map<String, dynamic>> room(String id) => _req('GET', '/api/rooms/$id');
  Future<Map<String, dynamic>> joinRoom(String id, {String? password}) =>
      _req('POST', '/api/rooms/$id/join', query: {if (password != null) 'password': password});
  Future<Map<String, dynamic>> leaveRoom(String id) => _req('POST', '/api/rooms/$id/leave');
  Future<Map<String, dynamic>> deleteRoom(String id) => _req('DELETE', '/api/rooms/$id');
  Future<Map<String, dynamic>> readyRoom(String id) => _req('POST', '/api/rooms/$id/ready');
  Future<Map<String, dynamic>> kickPlayer(String id, String target) =>
      _req('POST', '/api/rooms/$id/kick', query: {'target': target});
  Future<Map<String, dynamic>> startGame(String id) => _req('POST', '/api/rooms/$id/start');
  Future<Map<String, dynamic>> chatHistory(String id, {int limit = 100}) =>
      _req('GET', '/api/rooms/$id/chat', query: {'limit': '$limit'});
  Future<Map<String, dynamic>> gameHistory(String id) => _req('GET', '/api/rooms/$id/history');

  // ---- WebSocket URLs (با ساخت ایمن Uri) ----
  Uri _wsUri(String path, Map<String, String> params) {
    final baseUri = Uri.parse(baseUrl);
    final scheme = baseUri.scheme == 'https' ? 'wss' : 'ws';
    final port = baseUri.hasPort ? baseUri.port : (scheme == 'wss' ? 443 : 80);
    return Uri(
      scheme: scheme,
      host: baseUri.host,
      port: port,
      path: path,
      queryParameters: {
        ...params,
        'username': username ?? '',
        'api_key': apiKey,
        'token': session ?? '',
      },
    );
  }

  Uri wsRoomUri(String roomId) => _wsUri('/ws/room/$roomId', {});
  Uri wsUserUri() => _wsUri('/ws/user', {});
}

class SecureStore {
  static const _st = FlutterSecureStorage();
  static Future<String?> read(String k) async {
    try {
      return await _st.read(key: k);
    } catch (_) {
      return null;
    }
  }

  static Future<void> write(String k, String v) async {
    try {
      await _st.write(key: k, value: v);
    } catch (_) {}
  }

  static Future<void> del(String k) async {
    try {
      await _st.delete(key: k);
    } catch (_) {}
  }
}

// ============================================================================
// 4) وضعیت جهانی اپ
// ============================================================================
class AppState extends ChangeNotifier {
  AppState(this.api);
  final ApiService api;

  bool booted = false;
  bool needsSetup = true;
  UserModel? me;
  bool haptics = true;
  bool soundOn = true;
  bool notifOn = true;
  bool darkMode = true;
  bool serverOk = false;
  int pingMs = -1;
  int onlineCount = 0;
  List<Map> notifications = [];
  Map achDefs = {};
  Set<String> favoriteRooms = {};
  int dailyStreak = 0;
  DateTime? lastDailyClaim;
  int coins = 0;

  String get baseUrl => api.baseUrl;

  WebSocketChannel? _uws;
  StreamSubscription? _uwsSub;
  Timer? _uwsRetry;
  int _uwsTries = 0;
  bool _uwsStopped = false;

  bool get authed => me != null && api.session != null;

  void buzz([int ms = 40, int amp = 90]) {
    if (!haptics) return;
    try {
      Vibration.vibrate(duration: ms, amplitude: amp);
    } catch (_) {}
  }

  Future<void> _loadPrefs() async {
    final p = api.prefs;
    haptics = p.getBool('haptics') ?? true;
    soundOn = p.getBool('sound') ?? true;
    notifOn = p.getBool('notif') ?? true;
    darkMode = p.getBool('dark_mode') ?? true;
    coins = p.getInt('coins') ?? 0;
    dailyStreak = p.getInt('daily_streak') ?? 0;
    final lastStr = p.getString('last_daily_claim');
    if (lastStr != null) {
      try { lastDailyClaim = DateTime.parse(lastStr); } catch (_) {}
    }
    final favs = p.getStringList('favorite_rooms') ?? [];
    favoriteRooms = favs.toSet();
  }

  Future<void> _saveFavorites() async {
    await api.prefs.setStringList('favorite_rooms', favoriteRooms.toList());
  }

  void toggleFavorite(String roomId) {
    if (favoriteRooms.contains(roomId)) {
      favoriteRooms.remove(roomId);
    } else {
      favoriteRooms.add(roomId);
    }
    _saveFavorites();
    notifyListeners();
  }

  bool canClaimDaily() {
    if (lastDailyClaim == null) return true;
    final now = DateTime.now();
    return now.year != lastDailyClaim!.year ||
        now.month != lastDailyClaim!.month ||
        now.day != lastDailyClaim!.day;
  }

  Future<void> claimDaily() async {
    if (!canClaimDaily()) return;
    final now = DateTime.now();
    if (lastDailyClaim != null &&
        now.difference(lastDailyClaim!).inDays == 1) {
      dailyStreak++;
    } else if (lastDailyClaim != null) {
      dailyStreak = 1;
    } else {
      dailyStreak = 1;
    }
    lastDailyClaim = now;
    final dayIdx = ((dailyStreak - 1) % 7);
    coins += (dayIdx + 1) * 10;
    await api.prefs.setInt('coins', coins);
    await api.prefs.setInt('daily_streak', dailyStreak);
    await api.prefs.setString('last_daily_claim', now.toIso8601String());
    notifyListeners();
  }

  Future<void> boot() async {
    await _loadPrefs();
    final savedKey = await SecureStore.read('apiKey');
    if (savedKey != null && savedKey.isNotEmpty) {
      api.apiKey = savedKey;
      needsSetup = false;
    } else {
      needsSetup = true;
    }
    final manual = api.prefs.getString('manual_base');
    if (manual != null && manual.isNotEmpty) {
      api.baseUrl = manual;
    } else {
      await api.fetchBaseUrl();
      if (api.baseUrl.isEmpty) {
        final c = api.prefs.getString('base_url');
        if (c != null && c.isNotEmpty) api.baseUrl = c;
      }
    }
    await ping();
    final tok = await SecureStore.read('session');
    final uname = await SecureStore.read('username');
    if (tok != null && uname != null && tok.isNotEmpty) {
      api.session = tok;
      api.username = uname;
      try {
        final d = await api.me();
        me = UserModel.from(_m(d['user']));
      } catch (e) {
        debugPrint('Session restore failed: $e');
        api.session = null;
        api.username = null;
      }
    }
    if (authed) {
      loadAchievements();
      refreshNotifications();
      connectUserWs();
    }
    booted = true;
    notifyListeners();
  }

  Future<void> ping() async {
    final sw = Stopwatch()..start();
    try {
      final d = await api.health();
      serverOk = true;
      pingMs = sw.elapsedMilliseconds;
      onlineCount = _i(_gf(d, 'online'));
    } catch (e) {
      serverOk = false;
      pingMs = -1;
      debugPrint('Ping failed: $e');
    }
    notifyListeners();
  }

  Future<void> login(String u, String? p) async {
    final d = await api.login(u, p);
    api.session = _s(_gf(d, 'session'));
    api.username = _s(_gf(d, 'username'), u);
    await SecureStore.write('session', api.session!);
    await SecureStore.write('username', api.username!);
    me = UserModel.from(_m(_gf(d, 'user')));
    loadAchievements();
    refreshNotifications();
    connectUserWs();
    notifyListeners();
  }

  Future<void> register({required String username, String? password, String avatar = '🙂', String bio = ''}) async {
    final d = await api.register(username, password, avatar, bio);
    api.session = _s(_gf(d, 'session'));
    api.username = _s(_gf(d, 'username'), username);
    await SecureStore.write('session', api.session!);
    await SecureStore.write('username', api.username!);
    me = UserModel.from(_m(_gf(d, 'user')));
    loadAchievements();
    connectUserWs();
    notifyListeners();
  }

  Future<void> logout({bool silent = false}) async {
    _uwsStopped = true;
    _uwsRetry?.cancel();
    try {
      _uwsSub?.cancel();
      _uws?.sink.close();
    } catch (_) {}
    _uws = null;
    if (!silent) {
      try { await api.logout(); } catch (_) {}
    }
    api.session = null;
    me = null;
    notifications = [];
    await SecureStore.del('session');
    notifyListeners();
  }

  Future<void> refreshMe() async {
    try {
      final d = await api.me();
      me = UserModel.from(_m(_gf(d, 'user')));
      notifyListeners();
    } catch (e) {
      if (e is ApiError && e.message.contains('نشست')) await logout(silent: true);
    }
  }

  Future<void> loadAchievements() async {
    try {
      final d = await api.achievements();
      achDefs = _m(_gf(d, 'achievements'));
      notifyListeners();
    } catch (_) {}
  }

  Future<void> refreshNotifications() async {
    if (!authed) return;
    try {
      final d = await api.notifications();
      notifications = _l(_gf(d, 'notifications')).map(_m).toList();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> markAllRead() async {
    try {
      await api.markNotifsRead();
      notifications = [];
      notifyListeners();
    } catch (_) {}
  }

  // ---- WebSocket کاربر ----
  void connectUserWs() {
    _uwsStopped = false;
    _uwsTries = 0;
    _openUserWs();
  }

  Future<void> _openUserWs() async {
    if (_uwsStopped || api.session == null) return;
    try {
      final url = api.wsUserUri();
      debugPrint('🔌 UserWS: $url');
      final ch = WebSocketChannel.connect(url);
      await ch.ready.timeout(const Duration(seconds: 15));
      _uws = ch;
      _uwsTries = 0;
      _uwsSub = ch.stream.listen((raw) {
        try {
          final m = jsonDecode(raw);
          if (m is Map) _onUserMsg(m);
        } catch (_) {}
      }, onDone: () {
        _userWsClosed(ch.closeCode, ch.closeReason);
      }, onError: (e) {
        _userWsClosed(null, e.toString());
      });
    } catch (e) {
      _userWsClosed(null, e.toString());
    }
  }

  void _userWsClosed([int? code, String? reason]) {
    _uwsSub?.cancel();
    _uwsSub = null;
    _uws = null;
    if (_uwsStopped || me == null) return;
    if (_uwsTries < 6) {
      _uwsTries++;
      _uwsRetry?.cancel();
      _uwsRetry = Timer(Duration(seconds: 2 * _uwsTries), _openUserWs);
    }
  }

  void _onUserMsg(Map msg) {
    final t = _s(_gf(msg, 'type'));
    if (t == 'friend_request' || t == 'friend_accept' || t == 'game_result') {
      refreshNotifications();
      if (notifOn) {
        final title = t == 'friend_request'
            ? '🤝 درخواست دوستی جدید'
            : t == 'friend_accept'
                ? '✅ دوستی قبول شد'
                : _s(_gf(msg, 'title'), '🎮 نتیجه بازی');
        toast(title);
        buzz(40);
      }
    } else if (t == 'achievement') {
      final info = _m(_gf(msg, 'info'));
      if (notifOn) toast('🏅 دستاورد جدید: ${_s(_gf(info, 'title'))}', color: PColors.goldDark);
      refreshMe();
      buzz(80);
    }
    notifyListeners();
  }

  void setDarkMode(bool v) {
    darkMode = v;
    api.prefs.setBool('dark_mode', v);
    notifyListeners();
  }
}

// ============================================================================
// 5) ورودی اپ
// ============================================================================
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(
      [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: PColors.bg1,
    statusBarIconBrightness: Brightness.light,
  ));
  final prefs = await SharedPreferences.getInstance();
  final api = ApiService(prefs);
  final state = AppState(api);
  runApp(MultiProvider(
    providers: [ChangeNotifierProvider<AppState>(create: (_) => state..boot())],
    child: const PaskarApp(),
  ));
}

class PaskarApp extends StatelessWidget {
  const PaskarApp({super.key});

  ThemeData _theme(bool dark) {
    if (dark) {
      return ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        fontFamily: kFont,
        scaffoldBackgroundColor: PColors.bg1,
        colorScheme: const ColorScheme.dark(
          primary: PColors.gold,
          secondary: PColors.green,
          surface: PColors.panel,
          error: PColors.red,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent, elevation: 0, centerTitle: true,
          titleTextStyle: TextStyle(fontFamily: kFont, fontSize: 17, fontWeight: FontWeight.w800, color: PColors.text),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: PColors.panel,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          titleTextStyle: const TextStyle(fontFamily: kFont, fontSize: 16, color: PColors.text),
        ),
        snackBarTheme: const SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: PColors.panel2,
          contentTextStyle: TextStyle(fontFamily: kFont),
        ),
        dividerColor: Colors.white10,
        inputDecorationTheme: InputDecorationTheme(
          filled: true, fillColor: Colors.white.withOpacity(0.05),
          hintStyle: const TextStyle(color: PColors.sub, fontSize: 13),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: PColors.gold, width: 1.4),
          ),
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((s) =>
              s.contains(WidgetState.selected) ? PColors.gold : Colors.white54),
          trackColor: WidgetStateProperty.resolveWith((s) =>
              s.contains(WidgetState.selected) ? PColors.goldDark.withOpacity(.5) : Colors.white12),
        ),
      );
    } else {
      return ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        fontFamily: kFont,
        scaffoldBackgroundColor: PColors.lBg1,
        colorScheme: const ColorScheme.light(
          primary: PColors.goldDark,
          secondary: PColors.green,
          surface: PColors.lPanel,
          error: PColors.red,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent, elevation: 0, centerTitle: true,
          titleTextStyle: TextStyle(fontFamily: kFont, fontSize: 17, fontWeight: FontWeight.w800, color: PColors.lText),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: PColors.lPanel,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          titleTextStyle: const TextStyle(fontFamily: kFont, fontSize: 16, color: PColors.lText),
        ),
        dividerColor: Colors.black12,
        inputDecorationTheme: InputDecorationTheme(
          filled: true, fillColor: PColors.lBg2,
          hintStyle: const TextStyle(color: PColors.lSub, fontSize: 13),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: PColors.goldDark, width: 1.4),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(builder: (context, app, _) {
      return MaterialApp(
        title: 'پاسور',
        debugShowCheckedModeBanner: false,
        theme: _theme(app.darkMode),
        scaffoldMessengerKey: rootMessenger,
        builder: (context, child) => Directionality(
          textDirection: ui.TextDirection.rtl,
          child: Builder(builder: (ctx) => child ?? const SizedBox.shrink()),
        ),
        home: const SplashPage(),
      );
    });
  }
}

// ============================================================================
// 5.5) صفحه Setup
// ============================================================================
class SetupPage extends StatefulWidget {
  const SetupPage({super.key});
  @override
  State<SetupPage> createState() => _SetupPageState();
}

class _SetupPageState extends State<SetupPage> {
  final _keyCtrl = TextEditingController();
  bool _busy = false;

  @override
  void dispose() { _keyCtrl.dispose(); super.dispose(); }

  Future<void> _save() async {
    final key = _keyCtrl.text.trim();
    if (key.isEmpty) return toast('API Key را وارد کن', color: PColors.red);
    setState(() => _busy = true);
    try {
      final app = context.read<AppState>();
      app.api.apiKey = key;
      await SecureStore.write('apiKey', key);
      app.needsSetup = false;
      await app.ping();
      if (mounted) {
        toast('✅ API Key ذخیره شد', color: PColors.green);
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const AuthPage()));
      }
    } catch (e) {
      toast('خطا: $e', color: PColors.red);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft,
              colors: [PColors.bg2, PColors.bg1]),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(children: [
              const SizedBox(height: 20),
              const Text('🔑', style: TextStyle(fontSize: 54)),
              const SizedBox(height: 8),
              const Text('خوش اومدی!',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: PColors.gold)),
              const SizedBox(height: 8),
              const Text('برای شروع، API Key سرور را وارد کن',
                  style: TextStyle(color: PColors.sub, fontSize: 13)),
              const SizedBox(height: 24),
              Glass(
                padding: const EdgeInsets.all(18),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const Text('🔐 API Key سرور',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                  const SizedBox(height: 6),
                  const Text('این کلید برای احراز هویت لازم است.',
                      style: TextStyle(fontSize: 11, color: PColors.sub)),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _keyCtrl,
                    textDirection: ui.TextDirection.ltr,
                    style: const TextStyle(fontFamily: kFont, fontSize: 13),
                    decoration: const InputDecoration(
                      hintText: 'API Key را اینجا وارد کن',
                      prefixIcon: Icon(Icons.key_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),
                  GoldBtn(
                    text: 'ذخیره و ادامه',
                    icon: Icons.check_circle_outline,
                    loading: _busy,
                    onPressed: _save,
                  ),
                ]),
              ),
              const SizedBox(height: 16),
              const Text('بعداً می‌توانی از تنظیمات API Key را تغییر دهی',
                  style: TextStyle(fontSize: 10, color: PColors.sub)),
            ]),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// 6) اسپلش
// ============================================================================
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});
  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
  }

  @override
  void dispose() { _pulse.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(builder: (context, app, _) {
      if (app.booted && !_navigated) {
        _navigated = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (app.needsSetup) {
            Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const SetupPage()));
          } else if (app.authed) {
            Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const MainShellPage()));
          } else {
            Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const AuthPage()));
          }
        });
      }
      return Scaffold(
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [PColors.bg2, PColors.bg1],
            ),
          ),
          child: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              AnimatedBuilder(
                animation: _pulse,
                builder: (_, __) => Transform.scale(
                  scale: 1 + _pulse.value * 0.12,
                  child: Container(
                    width: 120, height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const RadialGradient(colors: [PColors.gold, PColors.goldDark]),
                      boxShadow: [BoxShadow(color: PColors.gold.withOpacity(.35), blurRadius: 40, spreadRadius: 6)],
                    ),
                    child: const Center(child: Text('🎴', style: TextStyle(fontSize: 56))),
                  ),
                ),
              ),
              const SizedBox(height: 26),
              const Text('پاسور', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: PColors.gold)),
              const SizedBox(height: 6),
              Text(
                app.needsSetup ? 'آماده‌سازی اولیه...'
                    : app.baseUrl.isEmpty ? 'دریافت آدرس سرور...'
                        : app.serverOk ? 'سرور متصل • ${fa(app.onlineCount)} آنلاین'
                            : 'در حال اتصال به سرور...',
                style: const TextStyle(color: PColors.sub, fontSize: 13),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: 170,
                child: Shimmer.fromColors(
                  baseColor: Colors.white12, highlightColor: PColors.gold.withOpacity(.6),
                  child: Container(height: 5, decoration: BoxDecoration(
                      color: Colors.white, borderRadius: BorderRadius.circular(8))),
                ),
              ),
            ]),
          ),
        ),
      );
    });
  }
}

// ============================================================================
// 7) احراز هویت
// ============================================================================
class AuthPage extends StatefulWidget {
  const AuthPage({super.key});
  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 2, vsync: this);

  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft,
              colors: [PColors.bg2, PColors.bg1]),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(children: [
              const SizedBox(height: 8),
              const Text('🎴', style: TextStyle(fontSize: 54)),
              const SizedBox(height: 4),
              const Text('پاسور', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: PColors.gold)),
              const Text('چهاربرگ • هفت خبیث • شلم • حکم',
                  style: TextStyle(color: PColors.sub, fontSize: 12)),
              const SizedBox(height: 22),
              Glass(
                padding: const EdgeInsets.all(18),
                child: Column(children: [
                  Container(
                    decoration: BoxDecoration(color: PColors.bg1, borderRadius: BorderRadius.circular(14)),
                    child: TabBar(
                      controller: _tab,
                      indicator: BoxDecoration(color: PColors.gold, borderRadius: BorderRadius.circular(12)),
                      labelColor: Colors.black,
                      unselectedLabelColor: PColors.sub,
                      labelStyle: const TextStyle(fontFamily: kFont, fontWeight: FontWeight.w800),
                      tabs: const [Tab(text: 'ورود'), Tab(text: 'ثبت‌نام')],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 330,
                    child: TabBarView(controller: _tab, children: const [_LoginForm(), _RegisterForm()]),
                  ),
                ]),
              ),
              const SizedBox(height: 16),
              Consumer<AppState>(builder: (context, app, _) => TextButton.icon(
                    onPressed: () => showConnectionSheet(context, app),
                    icon: const Icon(Icons.settings_outlined, size: 17),
                    label: Text(
                      app.serverOk
                          ? 'متصل به سرور (${fa(app.pingMs)}ms) — تنظیمات'
                          : 'اتصال سرور برقرار نیست — تنظیمات',
                      style: TextStyle(color: app.serverOk ? PColors.green : PColors.red, fontSize: 12),
                    ),
                  )),
            ]),
          ),
        ),
      ),
    );
  }
}

class _LoginForm extends StatefulWidget {
  const _LoginForm();
  @override
  State<_LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<_LoginForm> {
  final _u = TextEditingController();
  final _p = TextEditingController();
  bool _busy = false, _obscure = true;

  Future<void> _submit() async {
    final app = context.read<AppState>();
    if (_u.text.trim().isEmpty) return toast('نام کاربری را وارد کن');
    setState(() => _busy = true);
    try {
      await app.login(_u.text.trim(), _p.text.isEmpty ? null : _p.text);
      if (mounted) {
        app.buzz(60);
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const MainShellPage()));
      }
    } on ApiError catch (e) {
      toast(e.message, color: PColors.red);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      TextField(controller: _u, style: const TextStyle(fontFamily: kFont),
          decoration: const InputDecoration(hintText: 'نام کاربری', prefixIcon: Icon(Icons.person_outline))),
      const SizedBox(height: 12),
      TextField(
        controller: _p, obscureText: _obscure, style: const TextStyle(fontFamily: kFont),
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(
          hintText: 'رمز عبور (اختیاری)',
          prefixIcon: const Icon(Icons.lock_outline),
          suffixIcon: IconButton(
              icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 19),
              onPressed: () => setState(() => _obscure = !_obscure)),
        ),
      ),
      const Spacer(),
      GoldBtn(text: 'ورود به بازی', icon: Icons.login_rounded, loading: _busy, onPressed: _submit),
      const SizedBox(height: 8),
      Center(child: Text('ورود یعنی پذیرش قوانین اتاق‌ها 🙂',
          style: TextStyle(color: PColors.sub.withOpacity(.7), fontSize: 11))),
    ]);
  }
}

class _RegisterForm extends StatefulWidget {
  const _RegisterForm();
  @override
  State<_RegisterForm> createState() => _RegisterFormState();
}

class _RegisterFormState extends State<_RegisterForm> {
  final _u = TextEditingController();
  final _p = TextEditingController();
  final _bio = TextEditingController();
  String _avatar = '😎';
  bool _busy = false;

  Future<void> _submit() async {
    final app = context.read<AppState>();
    final uname = _u.text.trim();
    if (uname.length < 2) return toast('نام کاربری حداقل ۲ حرف است');
    setState(() => _busy = true);
    try {
      await app.register(
          username: uname, password: _p.text.isEmpty ? null : _p.text,
          avatar: _avatar, bio: _bio.text.trim());
      if (mounted) {
        app.buzz(80);
        toast('🎉 خوش اومدی $uname!', color: PColors.green);
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const MainShellPage()));
      }
    } on ApiError catch (e) {
      toast(e.message, color: PColors.red);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(
          child: TextField(controller: _u, style: const TextStyle(fontFamily: kFont),
              decoration: const InputDecoration(hintText: 'نام کاربری', isDense: true)),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => _pickAvatar(),
          child: Container(
            width: 50, height: 50,
            decoration: BoxDecoration(color: PColors.bg1, borderRadius: BorderRadius.circular(14),
                border: Border.all(color: PColors.gold.withOpacity(.6))),
            child: Center(child: Text(_avatar, style: const TextStyle(fontSize: 24))),
          ),
        ),
      ]),
      const SizedBox(height: 10),
      TextField(controller: _p, obscureText: true, style: const TextStyle(fontFamily: kFont),
          decoration: const InputDecoration(hintText: 'رمز عبور (اختیاری)', isDense: true)),
      const SizedBox(height: 10),
      TextField(controller: _bio, style: const TextStyle(fontFamily: kFont), maxLength: 200,
          decoration: const InputDecoration(hintText: 'بیو (اختیاری)', isDense: true, counterText: '')),
      const Spacer(),
      GoldBtn(text: 'ساخت حساب و شروع', icon: Icons.casino_rounded, loading: _busy, onPressed: _submit),
    ]);
  }

  void _pickAvatar() {
    showSheet(context, StatefulBuilder(builder: (ctx, setSt) {
      return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('آواتار خودت را انتخاب کن',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
        const SizedBox(height: 14),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final e in kAvatars)
            GestureDetector(
              onTap: () {
                setState(() => _avatar = e);
                Navigator.pop(ctx);
              },
              child: Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: _avatar == e ? PColors.gold.withOpacity(.25) : PColors.bg1,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _avatar == e ? PColors.gold : Colors.white10),
                ),
                child: Center(child: Text(e, style: const TextStyle(fontSize: 22))),
              ),
            ),
        ]),
      ]);
    }));
  }
}

void showConnectionSheet(BuildContext context, AppState app) {
  final baseCtrl = TextEditingController(text: app.api.baseUrl);
  final keyCtrl = TextEditingController(text: app.api.apiKey);
  showSheet(context, StatefulBuilder(builder: (ctx, setSt) {
    return SingleChildScrollView(
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Center(child: Container(width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(4)))),
        const SizedBox(height: 16),
        const Text('⚙️ تنظیمات اتصال به سرور',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
        const SizedBox(height: 6),
        Row(children: [
          Container(width: 9, height: 9, decoration: BoxDecoration(
              shape: BoxShape.circle, color: app.serverOk ? PColors.green : PColors.red)),
          const SizedBox(width: 6),
          Text(app.serverOk ? 'متصل — پینگ ${fa(app.pingMs)}ms' : 'قطع',
              style: TextStyle(color: app.serverOk ? PColors.green : PColors.red, fontSize: 12)),
          const Spacer(),
          if (app.api.baseUrl.isNotEmpty)
            Flexible(child: Text(app.api.baseUrl,
                style: const TextStyle(fontSize: 10, color: PColors.sub),
                overflow: TextOverflow.ellipsis, textDirection: ui.TextDirection.ltr)),
        ]),
        const SizedBox(height: 14),
        Text('آدرس سرور (Base URL) — خودکار از گیت‌هاب:',
            style: TextStyle(color: PColors.sub, fontSize: 12)),
        const SizedBox(height: 6),
        TextField(controller: baseCtrl, textDirection: ui.TextDirection.ltr,
            style: const TextStyle(fontFamily: kFont, fontSize: 12),
            decoration: const InputDecoration(hintText: 'https://xxxx.trycloudflare.com')),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: GhostBtn(text: 'دریافت خودکار', icon: Icons.cloud_download_outlined,
              onPressed: () async {
                final ok = await app.api.fetchBaseUrl(force: true);
                baseCtrl.text = app.api.baseUrl;
                await app.ping();
                setSt(() {});
                toast(ok ? '✅ آدرس به‌روز شد' : 'خطا در دریافت آدرس',
                    color: ok ? PColors.green : PColors.red);
              })),
          const SizedBox(width: 8),
          Expanded(child: GhostBtn(text: 'تست اتصال', icon: Icons.network_check_outlined,
              onPressed: () async {
                await app.ping();
                setSt(() {});
                toast(app.serverOk ? '✅ سرور آنلاین' : '❌ سرور در دسترس نیست',
                    color: app.serverOk ? PColors.green : PColors.red);
              })),
        ]),
        const SizedBox(height: 14),
        Text('API Key سرور:', style: TextStyle(color: PColors.sub, fontSize: 12)),
        const SizedBox(height: 6),
        TextField(controller: keyCtrl, textDirection: ui.TextDirection.ltr,
            style: const TextStyle(fontFamily: kFont, fontSize: 12),
            decoration: const InputDecoration(hintText: 'X-API-Key')),
        const SizedBox(height: 16),
        GoldBtn(text: 'ذخیره تنظیمات', icon: Icons.save_outlined, onPressed: () async {
          final manual = baseCtrl.text.trim();
          if (manual.isNotEmpty) {
            app.api.baseUrl = manual.replaceAll(RegExp(r'/+$'), '');
            await app.api.prefs.setString('manual_base', app.api.baseUrl);
          } else {
            await app.api.prefs.remove('manual_base');
          }
          final k = keyCtrl.text.trim();
          if (k.isNotEmpty) {
            app.api.apiKey = k;
            await SecureStore.write('apiKey', k);
          }
          await app.ping();
          if (ctx.mounted) Navigator.pop(ctx);
          toast('ذخیره شد', color: PColors.green);
        }),
      ]),
    );
  }));
}

// ============================================================================
// 8) پوسته اصلی
// ============================================================================
class MainShellPage extends StatefulWidget {
  const MainShellPage({super.key});
  @override
  State<MainShellPage> createState() => _MainShellPageState();
}

class _MainShellPageState extends State<MainShellPage> {
  int _idx = 0;
  final _titles = ['🏠 اتاق‌ها', '🏆 رتبه‌بندی', '🤝 دوستان', '👤 پروفایل'];
  Timer? _pingTimer;

  @override
  void initState() {
    super.initState();
    _pingTimer = Timer.periodic(const Duration(seconds: 45), (_) {
      if (mounted) context.read<AppState>().ping();
    });
    // نمایش daily reward اگر قابل دریافت باشد
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final app = context.read<AppState>();
      if (app.canClaimDaily()) {
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) showDailyRewardSheet(context);
        });
      }
    });
  }

  @override
  void dispose() { _pingTimer?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(builder: (context, app, _) {
      return Scaffold(
        appBar: AppBar(
          title: Text(_titles[_idx]),
          leading: Padding(
            padding: const EdgeInsets.all(9),
            child: Container(
              decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [PColors.gold, PColors.goldDark]),
                  borderRadius: BorderRadius.circular(10)),
              child: const Center(child: Text('🎴', style: TextStyle(fontSize: 17))),
            ),
          ),
          actions: [
            // Daily reward
            if (app.canClaimDaily())
              Stack(children: [
                IconButton(
                  icon: const Icon(Icons.card_giftcard, color: PColors.gold, size: 22),
                  onPressed: () => showDailyRewardSheet(context),
                ),
                Positioned(
                  top: 6, right: 6,
                  child: Container(width: 8, height: 8,
                      decoration: const BoxDecoration(color: PColors.red, shape: BoxShape.circle)),
                ),
              ]),
            // Connection
            GestureDetector(
              onTap: () async {
                await app.ping();
                toast(app.serverOk ? '✅ سرور آنلاین (${fa(app.pingMs)}ms)' : '❌ سرور آفلاین',
                    color: app.serverOk ? PColors.green : PColors.red);
              },
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 16),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.06), borderRadius: BorderRadius.circular(20)),
                child: Row(children: [
                  Container(width: 8, height: 8, decoration: BoxDecoration(
                      shape: BoxShape.circle, color: app.serverOk ? PColors.green : PColors.red)),
                  const SizedBox(width: 4),
                  Text('${fa(app.onlineCount)}', style: const TextStyle(fontSize: 11)),
                ]),
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const NotificationsPage())),
              icon: Stack(clipBehavior: Clip.none, children: [
                const Icon(Icons.notifications_outlined, size: 23),
                if (app.notifications.isNotEmpty)
                  Positioned(top: 0, right: -4, child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: PColors.red, shape: BoxShape.circle),
                    child: Text('${fa(app.notifications.length)}',
                        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                  )),
              ]),
            ),
            const SizedBox(width: 6),
          ],
        ),
        body: IndexedStack(index: _idx, children: const [
          RoomsPage(), LeaderboardPage(), FriendsPage(), ProfilePage(),
        ]),
        bottomNavigationBar: Container(
          margin: const EdgeInsets.all(14),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          decoration: BoxDecoration(
            color: PColors.panel,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white10),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(.35), blurRadius: 18, offset: const Offset(0, 6))],
          ),
          child: Row(children: [
            _navItem(0, Icons.meeting_room_outlined, 'اتاق‌ها'),
            _navItem(1, Icons.emoji_events_outlined, 'رتبه‌ها'),
            _navItem(2, Icons.people_outline_rounded, 'دوستان'),
            _navItem(3, Icons.person_outline_rounded, 'پروفایل'),
          ]),
        ),
      );
    });
  }

  Widget _navItem(int i, IconData ic, String label) {
    final sel = _idx == i;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          context.read<AppState>().buzz(15, 40);
          setState(() => _idx = i);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: sel ? PColors.gold.withOpacity(.16) : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(ic, size: 21, color: sel ? PColors.gold : PColors.sub),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 10.5,
                color: sel ? PColors.gold : PColors.sub,
                fontWeight: sel ? FontWeight.w800 : FontWeight.normal)),
          ]),
        ),
      ),
    );
  }
}

// ============================================================================
// Daily Reward Sheet
// ============================================================================
void showDailyRewardSheet(BuildContext context) {
  final app = context.read<AppState>();
  final canClaim = app.canClaimDaily();
  final currentDayIdx = canClaim
      ? ((app.dailyStreak) % 7)
      : (((app.dailyStreak - 1).clamp(0, 999)) % 7);
  showSheet(context, StatefulBuilder(builder: (ctx, setSt) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Center(child: Container(width: 40, height: 4,
          decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(4)))),
      const SizedBox(height: 14),
      const Text('🎁 پاداش روزانه',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: PColors.gold)),
      const SizedBox(height: 4),
      Text('🔥 ${fa(app.dailyStreak)} روز پیاپی',
          style: const TextStyle(color: PColors.sub, fontSize: 12)),
      const SizedBox(height: 14),
      Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
        for (int i = 0; i < kDailyRewards.length; i++) ...[
          Builder(builder: (_) {
            final r = kDailyRewards[i];
            final claimed = i < (app.dailyStreak % 7) || (!canClaim && i <= currentDayIdx);
            final isCurrent = i == currentDayIdx && canClaim;
            return Container(
              width: 80,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isCurrent ? PColors.gold.withOpacity(.2) : PColors.bg1,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isCurrent ? PColors.gold : (claimed ? PColors.green : Colors.white10),
                  width: isCurrent ? 2 : 1,
                ),
              ),
              child: Column(children: [
                Text(r['icon'], style: const TextStyle(fontSize: 24)),
                const SizedBox(height: 3),
                Text('روز ${fa(r['day'])}',
                    style: const TextStyle(fontSize: 10, color: PColors.sub)),
                const SizedBox(height: 2),
                Text(r['title'],
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800,
                        color: claimed ? PColors.green : PColors.text)),
                if (claimed) const Icon(Icons.check_circle, size: 12, color: PColors.green),
              ]),
            );
          }),
        ],
      ]),
      const SizedBox(height: 14),
      if (canClaim)
        GoldBtn(
          text: 'دریافت پاداش امروز',
          icon: Icons.card_giftcard,
          onPressed: () {
            app.claimDaily();
            app.buzz(100);
            setSt(() {});
            final reward = kDailyRewards[currentDayIdx];
            toast('🎉 دریافت شد: ${reward['title']}', color: PColors.green, seconds: 4);
            Future.delayed(const Duration(seconds: 2), () {
              if (ctx.mounted) Navigator.pop(ctx);
            });
          },
        )
      else
        const GhostBtn(text: '✅ پاداش امروز گرفته شده'),
    ]);
  }));
}

// ============================================================================
// 9) اتاق‌ها (با جستجو و علاقه‌مندی)
// ============================================================================
class RoomsPage extends StatefulWidget {
  const RoomsPage({super.key});
  @override
  State<RoomsPage> createState() => _RoomsPageState();
}

class _RoomsPageState extends State<RoomsPage> {
  String? _filter;
  String _query = '';
  bool _onlyFavorites = false;
  bool _onlyAvailable = false;
  List<Map> _rooms = [];
  bool _loading = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _load(silent: true));
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final app = context.read<AppState>();
      final d = await app.api.rooms(game: _filter);
      if (!mounted) return;
      setState(() {
        _rooms = _l(_gf(d, 'rooms')).map(_m).toList();
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
      if (!silent) toast(e is ApiError ? e.message : 'خطا در دریافت اتاق‌ها', color: PColors.red);
    }
  }

  Future<void> _join(Map r) async {
    final app = context.read<AppState>();
    final rid = _s(_gf(r, 'room_id'));
    String? pw;
    if (_b(_gf(r, 'has_password'))) {
      pw = await askTextDialog(context, '🔒 رمز اتاق', 'رمز اتاق را وارد کن', obscure: true);
      if (pw == null) return;
    }
    app.buzz(25);
    try {
      await app.api.joinRoom(rid, password: pw);
      if (mounted) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => RoomPage(roomId: rid)));
      }
    } on ApiError catch (e) {
      toast('❌ ${e.message}', color: PColors.red);
    }
  }

  Future<void> _quickMatch() async {
    final available = _rooms.where((r) {
      final players = _l(_gf(r, 'players')).length;
      final max = _i(_gf(r, 'max_players'), 4);
      final status = _s(_gf(r, 'status'));
      return status == 'waiting' && players < max && !_b(_gf(r, 'has_password'));
    }).toList();
    if (available.isEmpty) {
      return toast('🎲 اتاق آماده‌ای پیدا نشد. یکی بساز!', color: PColors.blue);
    }
    available.shuffle();
    await _join(available.first);
  }

  List<Map> get _filtered {
    return _rooms.where((r) {
      final name = _s(_gf(r, 'name')).toLowerCase();
      final host = _s(_gf(r, 'host')).toLowerCase();
      final rid = _s(_gf(r, 'room_id'));
      final app = context.read<AppState>();
      if (_query.isNotEmpty &&
          !name.contains(_query.toLowerCase()) &&
          !host.contains(_query.toLowerCase())) {
        return false;
      }
      if (_onlyFavorites && !app.favoriteRooms.contains(rid)) return false;
      if (_onlyAvailable) {
        final players = _l(_gf(r, 'players')).length;
        final max = _i(_gf(r, 'max_players'), 4);
        final status = _s(_gf(r, 'status'));
        if (status != 'waiting' || players >= max) return false;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return Stack(children: [
      RefreshIndicator(
        onRefresh: _load,
        color: PColors.gold,
        child: CustomScrollView(slivers: [
          // Search
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
              child: TextField(
                onChanged: (v) => setState(() => _query = v),
                style: const TextStyle(fontFamily: kFont),
                decoration: InputDecoration(
                  hintText: '🔍 جستجوی اتاق...',
                  isDense: true,
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(icon: const Icon(Icons.close, size: 17),
                          onPressed: () => setState(() => _query = ''))
                      : null,
                ),
              ),
            ),
          ),
          // Chips
          SliverToBoxAdapter(
            child: SizedBox(
              height: 52,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                children: [
                  _chip(null, 'همه', Icons.grid_view_rounded, PColors.gold),
                  for (final g in GameMeta.all.values)
                    _chip(g.type, '${g.icon} ${g.name}', null, g.color),
                ],
              ),
            ),
          ),
          // Filters
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(children: [
                FilterChip(
                  label: const Text('⭐ مورد علاقه', style: TextStyle(fontSize: 10.5)),
                  selected: _onlyFavorites,
                  selectedColor: PColors.gold.withOpacity(.3),
                  onSelected: (v) => setState(() => _onlyFavorites = v),
                ),
                const SizedBox(width: 6),
                FilterChip(
                  label: const Text('🟢 آزاد', style: TextStyle(fontSize: 10.5)),
                  selected: _onlyAvailable,
                  selectedColor: PColors.green.withOpacity(.3),
                  onSelected: (v) => setState(() => _onlyAvailable = v),
                ),
                const Spacer(),
                GhostBtn(text: '🎲 بازی سریع', onPressed: _quickMatch),
              ]),
            ),
          ),
          if (_loading)
            const SliverFillRemaining(
                child: Center(child: SpinKitFadingCircle(color: PColors.gold, size: 40)))
          else if (filtered.isEmpty)
            SliverFillRemaining(
              child: EmptyState(
                emoji: _onlyFavorites ? '⭐' : '🪑',
                title: _onlyFavorites ? 'اتاق مورد علاقه‌ای نداری' : 'اتاقی پیدا نشد',
                sub: _onlyFavorites ? 'اتاق‌ها را با ⭐ نشان‌دار کن' : 'اولین اتاق را بساز!',
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 90),
              sliver: SliverList.builder(
                itemCount: filtered.length,
                itemBuilder: (c, i) => RoomCard(
                  room: filtered[i],
                  onJoin: () => _join(filtered[i]),
                ),
              ),
            ),
        ]),
      ),
      Positioned(
        left: 18, bottom: 18,
        child: FloatingActionButton.extended(
          backgroundColor: PColors.gold,
          foregroundColor: Colors.black,
          onPressed: () => showCreateRoomSheet(context, (rid) {
            Navigator.push(context, MaterialPageRoute(builder: (_) => RoomPage(roomId: rid)));
          }),
          icon: const Icon(Icons.add_rounded),
          label: const Text('اتاق جدید',
              style: TextStyle(fontFamily: kFont, fontWeight: FontWeight.w800)),
        ),
      ),
    ]);
  }

  Widget _chip(String? val, String label, IconData? icon, Color color) {
    final sel = _filter == val;
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: ChoiceChip(
        label: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) Icon(icon, size: 14, color: sel ? Colors.black : PColors.sub),
          if (icon != null) const SizedBox(width: 4),
          Text(label, style: TextStyle(fontFamily: kFont, fontSize: 12,
              color: sel ? Colors.black : PColors.text,
              fontWeight: sel ? FontWeight.w800 : FontWeight.normal)),
        ]),
        selected: sel,
        selectedColor: color,
        backgroundColor: PColors.panel,
        side: BorderSide(color: sel ? color : Colors.white10),
        onSelected: (_) {
          setState(() => _filter = val);
          _load();
        },
      ),
    );
  }
}

class RoomCard extends StatelessWidget {
  final Map room;
  final VoidCallback onJoin;
  const RoomCard({super.key, required this.room, required this.onJoin});

  @override
  Widget build(BuildContext context) {
    final meta = GameMeta.of(_s(_gf(room, 'game_type')));
    final players = _l(_gf(room, 'players'));
    final max = _i(_gf(room, 'max_players'), 4);
    final status = _s(_gf(room, 'status'), 'waiting');
    final full = players.length >= max;
    final rid = _s(_gf(room, 'room_id'));
    final app = context.watch<AppState>();
    final isFav = app.favoriteRooms.contains(rid);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onJoin,
          child: Glass(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Stack(children: [
                Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(
                    color: meta.color.withOpacity(.18),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: meta.color.withOpacity(.5)),
                  ),
                  child: Center(child: Text(meta.icon, style: const TextStyle(fontSize: 24))),
                ),
                Positioned(
                  top: -4, right: -4,
                  child: GestureDetector(
                    onTap: () => app.toggleFavorite(rid),
                    child: Icon(
                      isFav ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: isFav ? PColors.gold : Colors.white24,
                      size: 20,
                    ),
                  ),
                ),
              ]),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Flexible(child: Text(_s(_gf(room, 'name')), overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5))),
                    if (_b(_gf(room, 'has_password')))
                      const Padding(padding: EdgeInsets.only(right: 5),
                          child: Icon(Icons.lock_rounded, size: 13, color: PColors.gold)),
                    if (_b(_gf(room, 'is_private')))
                      const Padding(padding: EdgeInsets.only(right: 5),
                          child: Icon(Icons.visibility_off_rounded, size: 13, color: PColors.sub)),
                  ]),
                  const SizedBox(height: 3),
                  GestureDetector(
                    onTap: () => showUserProfile(context, _s(_gf(room, 'host'))),
                    child: Text('میزبان: ${_s(_gf(room, 'host'))}',
                        style: const TextStyle(fontSize: 11, color: PColors.blue,
                            decoration: TextDecoration.underline)),
                  ),
                  const SizedBox(height: 5),
                  Row(children: [
                    Icon(Icons.people_rounded, size: 13, color: meta.color),
                    const SizedBox(width: 3),
                    Text('${fa(players.length)}/${fa(max)}', style: const TextStyle(fontSize: 11)),
                    const SizedBox(width: 10),
                    Text(meta.name, style: TextStyle(fontSize: 10.5, color: meta.color,
                        fontWeight: FontWeight.w700)),
                  ]),
                ]),
              ),
              Column(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: status == 'playing' ? PColors.red.withOpacity(.18)
                        : PColors.green.withOpacity(.18),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(status == 'playing' ? '🎮 در حال بازی' : '⏳ انتظار',
                      style: TextStyle(fontSize: 10,
                          color: status == 'playing' ? PColors.red : PColors.green)),
                ),
                const SizedBox(height: 7),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: full ? Colors.white10 : PColors.gold,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(full ? 'تماشا' : 'ورود',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800,
                          color: full ? PColors.sub : Colors.black)),
                ),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}

void showCreateRoomSheet(BuildContext context, void Function(String roomId) onCreated) {
  showSheet(context, CreateRoomSheet(onCreated: onCreated));
}

class CreateRoomSheet extends StatefulWidget {
  final void Function(String roomId) onCreated;
  const CreateRoomSheet({super.key, required this.onCreated});
  @override
  State<CreateRoomSheet> createState() => _CreateRoomSheetState();
}

class _CreateRoomSheetState extends State<CreateRoomSheet> {
  final _name = TextEditingController();
  final _pass = TextEditingController();
  final _target = TextEditingController(text: '1000');
  String _game = 'chahar_barg';
  int _maxP = 4;
  double _timeout = 30;
  bool _private = false, _spectators = true, _chat = true, _voice = false;
  bool _busy = false;

  GameMeta get meta => GameMeta.of(_game);

  Future<void> _create() async {
    final app = context.read<AppState>();
    if (_name.text.trim().isEmpty) return toast('نام اتاق را بنویس');
    setState(() => _busy = true);
    try {
      final body = <String, dynamic>{
        'name': _name.text.trim(),
        'game_type': _game,
        'max_players': _maxP.clamp(meta.minPlayers, meta.maxPlayers),
        if (_pass.text.isNotEmpty) 'password': _pass.text,
        'is_private': _private,
        'allow_spectators': _spectators,
        'chat_enabled': _chat,
        'voice_enabled': _voice,
        'turn_timeout': _timeout.round(),
      };
      if (_game == 'shelem') {
        final t = int.tryParse(_target.text.trim());
        if (t != null && t > 0) body['target_score'] = t;
      }
      final d = await app.api.createRoom(body);
      final rid = _s(_gf(_m(_gf(d, 'room')), 'room_id'));
      if (context.mounted) {
        Navigator.pop(context);
        app.buzz(50);
        widget.onCreated(rid);
      }
    } on ApiError catch (e) {
      toast(e.message, color: PColors.red);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Center(child: Container(width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(4)))),
        const SizedBox(height: 14),
        Row(children: [
          const Text('➕ ساخت اتاق جدید', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          const Spacer(),
          GhostBtn(text: '📖 قوانین', onPressed: () => showGameRules(context, _game)),
        ]),
        const SizedBox(height: 14),
        TextField(controller: _name, style: const TextStyle(fontFamily: kFont),
            decoration: const InputDecoration(hintText: 'نام اتاق', prefixIcon: Icon(Icons.door_front_door_outlined))),
        const SizedBox(height: 12),
        Text('نوع بازی:', style: TextStyle(color: PColors.sub, fontSize: 12)),
        const SizedBox(height: 6),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final g in GameMeta.all.values)
            ChoiceChip(
              label: Text('${g.icon} ${g.name}', style: TextStyle(fontFamily: kFont, fontSize: 12,
                  color: _game == g.type ? Colors.black : PColors.text)),
              selected: _game == g.type,
              selectedColor: g.color,
              backgroundColor: PColors.bg1,
              onSelected: (_) => setState(() {
                _game = g.type;
                _maxP = _maxP.clamp(g.minPlayers, g.maxPlayers);
              }),
            ),
        ]),
        const SizedBox(height: 4),
        Text(meta.desc, style: TextStyle(color: meta.color, fontSize: 11)),
        const SizedBox(height: 12),
        Row(children: [
          Text('ظرفیت: ${fa(_maxP)} نفر', style: const TextStyle(fontSize: 13)),
          Expanded(
            child: Slider(
              value: _maxP.toDouble(),
              min: meta.minPlayers.toDouble(),
              max: meta.maxPlayers.toDouble(),
              divisions: math.max(1, meta.maxPlayers - meta.minPlayers),
              activeColor: PColors.gold,
              onChanged: meta.minPlayers == meta.maxPlayers
                  ? null
                  : (v) => setState(() => _maxP = v.round()),
            ),
          ),
        ]),
        Row(children: [
          Text('زمان هر نوبت: ${fa(_timeout.round())} ثانیه', style: const TextStyle(fontSize: 13)),
          Expanded(
            child: Slider(
              value: _timeout, min: 10, max: 120, divisions: 22,
              activeColor: PColors.blue,
              onChanged: (v) => setState(() => _timeout = v),
            ),
          ),
        ]),
        if (_game == 'shelem') ...[
          const SizedBox(height: 4),
          TextField(controller: _target, keyboardType: TextInputType.number,
              style: const TextStyle(fontFamily: kFont),
              decoration: const InputDecoration(hintText: 'امتیاز هدف شلم (مثلاً 1000)',
                  prefixIcon: Icon(Icons.flag_outlined))),
        ],
        const SizedBox(height: 10),
        TextField(controller: _pass, obscureText: true, style: const TextStyle(fontFamily: kFont),
            decoration: const InputDecoration(hintText: 'رمز اتاق (اختیاری)',
                prefixIcon: Icon(Icons.lock_outline))),
        const SizedBox(height: 4),
        SwitchListTile(value: _private, onChanged: (v) => setState(() => _private = v),
            title: const Text('اتاق خصوصی', style: TextStyle(fontSize: 13)),
            secondary: const Icon(Icons.visibility_off_outlined, size: 19)),
        SwitchListTile(value: _spectators, onChanged: (v) => setState(() => _spectators = v),
            title: const Text('اجازه تماشاچی', style: TextStyle(fontSize: 13)),
            secondary: const Icon(Icons.remove_red_eye_outlined, size: 19)),
        SwitchListTile(value: _chat, onChanged: (v) => setState(() => _chat = v),
            title: const Text('چت اتاق', style: TextStyle(fontSize: 13)),
            secondary: const Icon(Icons.chat_bubble_outline, size: 19)),
        SwitchListTile(value: _voice, onChanged: (v) => setState(() => _voice = v),
            title: const Text('ویس (پشتیبانی وب)', style: TextStyle(fontSize: 13)),
            secondary: const Icon(Icons.mic_none_outlined, size: 19)),
        const SizedBox(height: 8),
        GoldBtn(text: 'ساخت اتاق', icon: Icons.add_circle_outline_rounded,
            loading: _busy, onPressed: _create),
      ]),
    );
  }
}

void showGameRules(BuildContext context, String gameType) {
  final meta = GameMeta.of(gameType);
  showSheet(context, Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [
      Text(meta.icon, style: const TextStyle(fontSize: 30)),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(meta.name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
        Text(meta.desc, style: const TextStyle(fontSize: 11, color: PColors.sub)),
      ])),
    ]),
    const SizedBox(height: 16),
    const Text('📖 قوانین بازی', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
    const SizedBox(height: 8),
    for (final r in meta.rules)
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(r, style: const TextStyle(fontSize: 12.5, height: 1.5)),
      ),
  ]));
}

// ============================================================================
// 10) نشست اتاق (WebSocket بهبودیافته)
// ============================================================================
class RoomSession extends ChangeNotifier {
  RoomSession({required this.api, required this.roomId, required this.me, required this.buzz});

  final ApiService api;
  final String roomId;
  final String me;
  final void Function([int ms, int amp]) buzz;

  Map room = {};
  List<Map> chat = [];
  Map? gameState;
  Map? myState;
  String mode = 'lobby';
  bool connected = false;
  String connInfo = 'در حال اتصال...';
  String lastError = '';
  final Set<String> online = {};
  final Set<String> typing = {};
  final Map<String, Timer> _typingTimers = {};
  List<Map> emotes = [];
  int _emoteId = 0;
  bool closedByUser = false;
  bool disposed = false;
  int _tries = 0;

  WebSocketChannel? _ws;
  StreamSubscription? _sub;
  Timer? _pingTimer;

  void Function(String msg, {Color? color, int seconds})? onToast;
  VoidCallback? onFatalClose;

  bool get isPlayer => _l(_gf(room, 'players')).contains(me);
  bool get isHost => _s(_gf(room, 'host')) == me;
  bool get myReady => _l(_gf(room, 'ready')).contains(me);
  int get turnTimeout => _i(_gf(room, 'turn_timeout'), 30);

  Future<void> loadInitial() async {
    try {
      final d = await api.room(roomId);
      room = _m(_gf(d, 'room'));
      if (mode == 'lobby') {
        final st = _s(_gf(room, 'status'));
        mode = st == 'playing' ? 'playing' : st == 'finished' ? 'finished' : 'lobby';
      }
      _notify();
    } catch (e) {
      debugPrint('loadInitial failed: $e');
    }
  }

  Future<void> connect() async {
    if (closedByUser || disposed) return;
    connInfo = 'در حال اتصال به اتاق...';
    lastError = '';
    _notify();
    try {
      // بررسی مقدماتی
      if (api.baseUrl.isEmpty) throw Exception('آدرس سرور تنظیم نشده');
      if (api.session == null || api.username == null) {
        throw Exception('نشست شما معتبر نیست. لطفاً دوباره وارد شوید.');
      }
      if (api.apiKey.isEmpty || api.apiKey == ApiService.defaultApiKey) {
        throw Exception('API Key تنظیم نشده است');
      }

      final url = api.wsRoomUri(roomId);
      debugPrint('🔌 WS connecting: $url');
      
      final ch = WebSocketChannel.connect(url);
      
      // Timeout برای اتصال
      try {
        await ch.ready.timeout(const Duration(seconds: 15));
      } on TimeoutException {
        try { ch.sink.close(); } catch (_) {}
        throw Exception('سرور پاسخ نداد (timeout پس از ۱۵ ثانیه). اتصال اینترنت یا سرور را بررسی کن.');
      }

      _ws = ch;
      connected = true;
      _tries = 0;
      connInfo = '';
      lastError = '';
      _sub = ch.stream.listen(
        _onData,
        onDone: () {
          final code = ch.closeCode;
          final reason = ch.closeReason;
          debugPrint('🔌 WS closed: code=$code reason=$reason');
          _closed(code, reason);
        },
        onError: (e, st) {
          debugPrint('🔌 WS error: $e');
          _closed(null, e.toString());
        },
        cancelOnError: false,
      );
      _pingTimer?.cancel();
      _pingTimer = Timer.periodic(const Duration(seconds: 25), (_) => _send({'type': 'ping'}));
      _notify();
    } catch (e) {
      debugPrint('🔌 WS connect failed: $e');
      _closed(null, e.toString());
    }
  }

  String _translateCloseReason(int? code, String? reason) {
    if (reason != null && reason.isNotEmpty) {
      // ترجمه‌های رایج
      if (reason.toLowerCase().contains('invalid api key')) {
        return 'API Key نامعتبر است. از تنظیمات اصلاح کنید.';
      }
      if (reason.toLowerCase().contains('invalid session')) {
        return 'نشست شما منقضی شده. دوباره وارد شوید.';
      }
      if (reason.toLowerCase().contains('room not found')) {
        return 'اتاق پیدا نشد. ممکن است حذف شده باشد.';
      }
      if (reason.toLowerCase().contains('not in room')) {
        return 'شما در این اتاق عضو نیستید.';
      }
      return reason;
    }
    if (code == null) return 'اتصال برقرار نشد';
    switch (code) {
      case 1000: return 'اتصال به صورت عادی بسته شد';
      case 1001: return 'سرور در حال ترک است';
      case 1006: return 'اتصال به طور غیرعادی قطع شد (شبکه را چک کن)';
      case 1008: return 'دسترسی غیرمجاز (Policy Violation)';
      case 1011: return 'خطای داخلی سرور';
      case 1012: return 'سرور در حال راه‌اندازی مجدد';
      case 1013: return 'بعداً دوباره تلاش کن';
      default: return 'قطع شد با کد $code';
    }
  }

  void _closed([int? closeCode, String? closeReason]) {
    _sub?.cancel();
    _sub = null;
    _ws = null;
    connected = false;
    _pingTimer?.cancel();
    if (disposed || closedByUser) return;

    final friendlyMsg = _translateCloseReason(closeCode, closeReason);
    lastError = friendlyMsg;

    // اگر کد 1008 بود (policy violation)، تلاش مجدد فایده ندارد
    if (closeCode == 1008) {
      connInfo = '❌ $friendlyMsg';
      onToast?.call('❌ خطا در اتصال: $friendlyMsg', color: PColors.red, seconds: 6);
      _notify();
      // پس از 3 ثانیه از اتاق خارج شو
      Future.delayed(const Duration(seconds: 3), () {
        if (!disposed) onFatalClose?.call();
      });
      return;
    }

    if (_tries < 10) {
      _tries++;
      connInfo = 'تلاش ${fa(_tries)} از ۱۰ • $friendlyMsg';
      _notify();
      final delay = math.min(2 * _tries, 10);
      Future.delayed(Duration(seconds: delay), connect);
    } else {
      connInfo = '❌ $friendlyMsg';
      onToast?.call('❌ اتصال برقرار نشد: $friendlyMsg', color: PColors.red, seconds: 8);
      _notify();
    }
  }

  void _onData(dynamic raw) {
    Map msg;
    try {
      msg = jsonDecode(raw);
    } catch (e) {
      debugPrint('WS JSON parse error: $e');
      return;
    }
    final t = _s(_gf(msg, 'type'));
    switch (t) {
      case 'welcome':
        room = _m(_gf(msg, 'room'));
        final st = _s(_gf(room, 'status'));
        mode = st == 'playing' ? 'playing' : st == 'finished' ? 'finished' : 'lobby';
        break;
      case 'chat_history':
        chat = _l(_gf(msg, 'messages')).map(_m).toList();
        break;
      case 'chat':
        chat.add(msg);
        if (chat.length > 200) chat.removeRange(0, chat.length - 200);
        break;
      case 'typing':
        final u = _s(_gf(msg, 'username'));
        if (u == me) break;
        typing.add(u);
        _typingTimers[u]?.cancel();
        _typingTimers[u] = Timer(const Duration(seconds: 3), () {
          typing.remove(u);
          _typingTimers.remove(u);
          _notify();
        });
        break;
      case 'emote':
        final id = _emoteId++;
        emotes.add({
          'id': id, 'emoji': _s(_gf(msg, 'emoji'), '👍'),
          'username': _s(_gf(msg, 'username')),
        });
        Future.delayed(const Duration(milliseconds: 2600), () {
          emotes.removeWhere((e) => e['id'] == id);
          _notify();
        });
        break;
      case 'ready_update':
        room['ready'] = _l(_gf(msg, 'ready'));
        break;
      case 'player_joined':
        room = _m(_gf(msg, 'room'));
        break;
      case 'player_left':
        final u = _s(_gf(msg, 'username'));
        _l(_gf(room, 'players')).remove(u);
        final rd = _gf(room, 'ready');
        if (rd is List) rd.remove(u);
        break;
      case 'user_online':
        online.add(_s(_gf(msg, 'username')));
        break;
      case 'user_offline':
        online.remove(_s(_gf(msg, 'username')));
        break;
      case 'game_started':
        gameState = _m(_gf(msg, 'state'));
        mode = 'playing';
        buzz(70, 140);
        break;
      case 'game_update':
        gameState = _m(_gf(msg, 'state'));
        break;
      case 'personal_state':
        myState = _m(_gf(msg, 'state'));
        gameState = Map.of(myState!);
        break;
      case 'tick':
        if (gameState != null) {
          gameState!['time_left'] = _gf(msg, 'time_left');
          gameState!['current_turn'] = _gf(msg, 'current_turn');
        }
        break;
      case 'auto_played':
        gameState = _m(_gf(msg, 'state'));
        break;
      case 'game_over':
        gameState = _m(_gf(msg, 'state'));
        mode = 'finished';
        break;
      case 'kicked':
        onToast?.call('🚫 از اتاق اخراج شدید', color: PColors.red);
        onFatalClose?.call();
        break;
      case 'room_closed':
        onToast?.call('اتاق توسط میزبان بسته شد');
        onFatalClose?.call();
        break;
      case 'error':
        onToast?.call('❌ ${_s(_gf(msg, 'message'), 'خطا')}', color: PColors.red);
        break;
      case 'pong':
        // heartbeat ok
        break;
      default:
        break;
    }
    _notify();
  }

  void _notify() {
    if (!disposed) notifyListeners();
  }

  void _send(Map m) {
    if (connected && _ws != null) {
      try {
        _ws!.sink.add(jsonEncode(m));
      } catch (e) {
        debugPrint('WS send error: $e');
      }
    }
  }

  void sendChat(String text, {String? to}) {
    if (to != null) {
      _send({'type': 'whisper', 'to': to, 'message': text});
    } else {
      _send({'type': 'chat', 'message': text});
    }
  }
  void sendTyping() => _send({'type': 'typing'});
  void sendEmote(String e) {
    _send({'type': 'emote', 'emoji': e});
    buzz(15, 40);
  }

  void wsToggleReady() {
    _send({'type': 'ready'});
    buzz(30);
  }

  void playCard(int i, {String? suit}) => _send({
        'type': 'game_action', 'action': 'play_card',
        'data': {'card_index': i, if (suit != null) 'suit': suit},
      });
  void bid(dynamic amount) => _send({
        'type': 'game_action', 'action': 'bid',
        'data': {'amount': amount},
      });
  void selectHokm(String suit) => _send({
        'type': 'game_action', 'action': 'select_hokm',
        'data': {'suit': suit},
      });
  void autoPlay() => _send({'type': 'game_action', 'action': 'auto'});
  void requestState() => _send({'type': 'game_action', 'action': 'state'});

  void backToLobby() {
    mode = 'lobby';
    gameState = null;
    myState = null;
    loadInitial();
    _notify();
  }

  Future<void> leave() async {
    closedByUser = true;
    try { await api.leaveRoom(roomId); } catch (_) {}
    _teardown();
  }

  void _teardown() {
    _pingTimer?.cancel();
    _sub?.cancel();
    for (final t in _typingTimers.values) t.cancel();
    try { _ws?.sink.close(); } catch (_) {}
  }

  @override
  void dispose() {
    disposed = true;
    _teardown();
    super.dispose();
  }
}

// ============================================================================
// 11) صفحه اتاق
// ============================================================================
class RoomPage extends StatefulWidget {
  final String roomId;
  const RoomPage({super.key, required this.roomId});
  @override
  State<RoomPage> createState() => _RoomPageState();
}

class _RoomPageState extends State<RoomPage> {
  late final RoomSession session;
  late final AppState app;

  @override
  void initState() {
    super.initState();
    app = Provider.of<AppState>(context, listen: false);
    session = RoomSession(
      api: app.api, roomId: widget.roomId,
      me: app.api.username ?? '', buzz: app.buzz,
    );
    session.onToast = (m, {color, seconds}) => toast(m, color: color, seconds: seconds ?? 3);
    session.onFatalClose = () {
      if (mounted) Navigator.of(context).pop();
    };
    session.loadInitial();
    session.connect();
  }

  Future<bool> _exit() async {
    if (session.mode == 'playing') {
      final ok = await confirmDialog(context, 'خروج از بازی',
          'اگر الان خارج شوی، بازی بدون تو ادامه پیدا می‌کند. مطمئنی؟', ok: 'خروج');
      if (!ok) return false;
    }
    await session.leave();
    return true;
  }

  @override
  void dispose() { session.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _exit,
      child: ChangeNotifierProvider<RoomSession>.value(
        value: session,
        child: Consumer<RoomSession>(builder: (context, s, _) {
          final meta = GameMeta.of(_s(_gf(s.room, 'game_type')));
          return Scaffold(
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.logout_rounded, color: PColors.red),
                onPressed: () async {
                  if (await _exit() && mounted) Navigator.of(context).pop();
                },
              ),
              title: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(meta.icon),
                const SizedBox(width: 6),
                Flexible(child: Text(_s(_gf(s.room, 'name'), 'اتاق'), overflow: TextOverflow.ellipsis)),
              ]),
              actions: [
                IconButton(
                  tooltip: 'قوانین بازی',
                  icon: const Icon(Icons.menu_book_outlined, size: 21, color: PColors.gold),
                  onPressed: () => showGameRules(context, _s(_gf(s.room, 'game_type'))),
                ),
                IconButton(
                  tooltip: 'تاریخچه بازی‌ها',
                  icon: const Icon(Icons.history_rounded, size: 21),
                  onPressed: () => showRoomHistory(context, app.api, widget.roomId),
                ),
                IconButton(
                  tooltip: 'اشتراک‌گذاری اتاق',
                  icon: const Icon(Icons.share_rounded, size: 20),
                  onPressed: () {
                    Share.share(
                        '🎴 به اتاق «${_s(_gf(s.room, 'name'))}» در اپ پاسور بپیوند!\nکد اتاق: ${widget.roomId}');
                  },
                ),
                if (s.isHost)
                  IconButton(
                    tooltip: 'حذف اتاق',
                    icon: const Icon(Icons.delete_outline_rounded, size: 21, color: PColors.red),
                    onPressed: () async {
                      final ok = await confirmDialog(context, 'حذف اتاق',
                          'اتاق برای همه بسته می‌شود. مطمئنی؟', ok: 'حذف');
                      if (!ok) return;
                      try {
                        await app.api.deleteRoom(widget.roomId);
                        session.closedByUser = true;
                        if (mounted) Navigator.of(context).pop();
                      } on ApiError catch (e) {
                        toast(e.message, color: PColors.red);
                      }
                    },
                  ),
                const SizedBox(width: 2),
              ],
            ),
            body: SafeArea(
              child: Stack(children: [
                Column(children: [
                  Expanded(child: s.mode == 'lobby' ? const LobbyView() : const GameBoard()),
                  const EmoteBar(),
                  const ChatBar(),
                ]),
                const EmoteOverlay(),
                if (!s.connected && s.connInfo.isNotEmpty)
                  Positioned(
                    top: 6, left: 16, right: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                          color: PColors.red.withOpacity(.18),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: PColors.red.withOpacity(.5))),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Row(children: [
                          const SizedBox(width: 14, height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: PColors.red)),
                          const SizedBox(width: 10),
                          Expanded(child: Text(s.connInfo,
                              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700))),
                        ]),
                        if (s.lastError.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text('🔍 تشخیص: ${s.lastError}',
                                style: const TextStyle(fontSize: 10, color: PColors.sub)),
                          ),
                      ]),
                    ),
                  ),
              ]),
            ),
          );
        }),
      ),
    );
  }
}

class LobbyView extends StatelessWidget {
  const LobbyView({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<RoomSession>();
    final meta = GameMeta.of(_s(_gf(s.room, 'game_type')));
    final players = _l(_gf(s.room, 'players')).map(_s).toList();
    final max = _i(_gf(s.room, 'max_players'), 4);
    final ready = _l(_gf(s.room, 'ready')).map(_s).toList();
    final allReady = players.isNotEmpty && players.every(ready.contains);
    final canStart = players.length >= meta.minPlayers && allReady;

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
      children: [
        Glass(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 46, height: 46,
                decoration: BoxDecoration(
                    color: meta.color.withOpacity(.18), borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: meta.color.withOpacity(.5))),
                child: Center(child: Text(meta.icon, style: const TextStyle(fontSize: 22))),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(meta.name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                Text(meta.desc, style: const TextStyle(fontSize: 11, color: PColors.sub)),
              ])),
              Column(children: [
                Text('${fa(players.length)}/${fa(max)}',
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: PColors.gold)),
                const Text('بازیکن', style: TextStyle(fontSize: 10, color: PColors.sub)),
              ]),
            ]),
            const SizedBox(height: 10),
            Wrap(spacing: 6, runSpacing: 6, children: [
              InfoChip(icon: Icons.timer_outlined, label: 'نوبت: ${fa(s.turnTimeout)}s'),
              if (_gf(s.room, 'target_score') != null)
                InfoChip(icon: Icons.flag_outlined, label: 'هدف: ${fa(_gf(s.room, 'target_score'))}'),
              if (_b(_gf(s.room, 'has_password'))) InfoChip(icon: Icons.lock_rounded, label: 'رمزدار'),
              if (_b(_gf(s.room, 'chat_enabled'))) InfoChip(icon: Icons.chat_bubble_outline, label: 'چت'),
              InfoChip(icon: Icons.remove_red_eye_outlined,
                  label: 'تماشاچی: ${fa(_l(_gf(s.room, 'spectators')).length)}'),
            ]),
          ]),
        ),
        const SizedBox(height: 10),
        Glass(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('👥 بازیکنان', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
            const SizedBox(height: 10),
            for (final p in players) _playerRow(context, s, p, ready.contains(p)),
            for (int i = players.length; i < max; i++)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: Colors.white12, style: BorderStyle.solid),
                ),
                child: const Row(children: [
                  Icon(Icons.add_rounded, color: PColors.sub, size: 18),
                  SizedBox(width: 8),
                  Text('جای خالی...', style: TextStyle(color: PColors.sub, fontSize: 12)),
                ]),
              ),
          ]),
        ),
        const SizedBox(height: 10),
        if (s.isPlayer)
          GoldBtn(
            text: s.myReady ? '✅ آماده‌ام (لغو)' : 'آماده‌ام!',
            icon: s.myReady ? Icons.check_circle : Icons.back_hand_outlined,
            color: s.myReady ? PColors.green : PColors.gold,
            onPressed: s.wsToggleReady,
          ),
        const SizedBox(height: 8),
        if (s.isHost)
          GoldBtn(
            text: canStart ? '🚀 شروع بازی' : 'منتظر آماده شدن همه...',
            icon: Icons.play_arrow_rounded,
            color: canStart ? PColors.green : PColors.panel2,
            onPressed: canStart
                ? () async {
                    try {
                      await s.api.startGame(s.roomId);
                    } on ApiError catch (e) {
                      toast(e.message, color: PColors.red);
                    }
                  }
                : null,
          )
        else
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                s.mode == 'lobby' ? '⏳ منتظر شروع توسط میزبان (${_s(_gf(s.room, 'host'))})...' : '',
                style: const TextStyle(color: PColors.sub, fontSize: 12),
              ),
            ),
          ),
        const SizedBox(height: 10),
        Glass(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('💬 گفتگو', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
            const SizedBox(height: 8),
            SizedBox(height: 190, child: ChatList(messages: s.chat)),
          ]),
        ),
      ],
    );
  }

  Widget _playerRow(BuildContext context, RoomSession s, String p, bool isReady) {
    final isMe = p == s.me;
    final isHost = p == _s(_gf(s.room, 'host'));
    return InkWell(
      borderRadius: BorderRadius.circular(13),
      onTap: () => showUserProfile(context, p),
      onLongPress: (s.isHost && !isMe)
          ? () async {
              final ok = await confirmDialog(context, 'اخراج بازیکن', '$p از اتاق اخراج شود؟', ok: 'اخراج');
              if (!ok) return;
              try {
                await s.api.kickPlayer(s.roomId, p);
                toast('$p اخراج شد');
              } on ApiError catch (e) {
                toast(e.message, color: PColors.red);
              }
            }
          : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isReady ? PColors.green.withOpacity(.08) : Colors.white.withOpacity(.03),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: isReady ? PColors.green.withOpacity(.4) : Colors.white10),
        ),
        child: Row(children: [
          AvatarView(emoji: '🙂', size: 34, online: s.online.contains(p) || isMe),
          const SizedBox(width: 9),
          Expanded(
            child: Row(children: [
              Flexible(child: Text(p, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5,
                      color: isMe ? PColors.gold : PColors.blue,
                      decoration: TextDecoration.underline))),
              if (isMe)
                const Padding(padding: EdgeInsets.only(right: 5),
                    child: Text('(من)', style: TextStyle(fontSize: 10, color: PColors.gold))),
              if (isHost)
                const Padding(padding: EdgeInsets.only(right: 5),
                    child: Text('👑', style: TextStyle(fontSize: 11))),
            ]),
          ),
          Icon(isReady ? Icons.check_circle : Icons.cancel_outlined,
              size: 19, color: isReady ? PColors.green : Colors.white24),
          const SizedBox(width: 4),
          Text(isReady ? 'آماده' : 'ناآماده',
              style: TextStyle(fontSize: 10.5, color: isReady ? PColors.green : PColors.sub)),
        ]),
      ),
    );
  }
}

class GameBoard extends StatefulWidget {
  const GameBoard({super.key});
  @override
  State<GameBoard> createState() => _GameBoardState();
}

class _GameBoardState extends State<GameBoard> {
  int? _selected;
  bool _sorted = true;
  bool _celebrated = false;
  late final ConfettiController _confetti;
  final _bidCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(duration: const Duration(seconds: 4));
  }

  @override
  void dispose() {
    _confetti.dispose();
    _bidCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<RoomSession>();
    final st = s.gameState;
    if (st == null) {
      return const Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SpinKitFadingCircle(color: PColors.gold, size: 36),
          SizedBox(height: 12),
          Text('در حال دریافت وضعیت بازی...', style: TextStyle(color: PColors.sub, fontSize: 12)),
        ]),
      );
    }
    final gt = _s(_gf(s.room, 'game_type'));
    final finished = _b(_gf(st, 'finished')) || s.mode == 'finished';
    final turn = _s(_gf(st, 'current_turn'));
    final myTurn = s.isPlayer && !finished && turn == s.me;
    final winners = _l(_gf(st, 'winners')).map(_s).toList();
    if (_s(_gf(st, 'winner')).isNotEmpty && !winners.contains(_s(_gf(st, 'winner')))) {
      winners.add(_s(_gf(st, 'winner')));
    }
    final iWon = winners.contains(s.me);
    if (finished && !_celebrated) {
      _celebrated = true;
      if (iWon) {
        _confetti.play();
        s.buzz(150, 200);
      }
    }

    return Stack(children: [
      Column(children: [
        _ScoreBar(st: st, gt: gt, s: s),
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: const RadialGradient(colors: [PColors.felt1, PColors.felt2]),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: PColors.goldDark.withOpacity(.55), width: 2),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(.4), blurRadius: 18)],
            ),
            child: Center(child: _tableArea(st, gt, s)),
          ),
        ),
        _TurnBar(st: st, s: s, myTurn: myTurn),
        if (gt == 'shelem' && _s(_gf(st, 'phase')) == 'bidding' && myTurn) _bidPanel(s, st),
        if (_s(_gf(st, 'phase')) == 'select_hokm' && _s(_gf(st, 'hakem')) == s.me)
          _suitPicker(s),
        _HandArea(
          s: s, st: st, myTurn: myTurn, selected: _selected, sorted: _sorted,
          onToggleSort: () => setState(() => _sorted = !_sorted),
          onCardTap: (i, card) => _cardTap(s, gt, i, card),
        ),
      ]),
      Align(
        alignment: Alignment.topCenter,
        child: ConfettiWidget(
          confettiController: _confetti,
          blastDirectionality: BlastDirectionality.explosive,
          shouldLoop: false, numberOfParticles: 35, gravity: 0.18,
          colors: const [PColors.gold, PColors.green, PColors.red, PColors.blue, Colors.white],
        ),
      ),
      if (finished) _ResultOverlay(st: st, s: s, winners: winners, iWon: iWon),
    ]);
  }

  void _cardTap(RoomSession s, String gt, int i, Map card) {
    if (_selected == i) {
      if (gt == 'haft_khabis' && _s(_gf(card, 'rank')) == '10') {
        _pickSuitForPlay(s, i);
      } else {
        s.playCard(i);
      }
      setState(() => _selected = null);
      s.buzz(25);
    } else {
      setState(() => _selected = i);
      s.buzz(12, 40);
    }
  }

  void _pickSuitForPlay(RoomSession s, int i) {
    showSheet(context, Column(mainAxisSize: MainAxisSize.min, children: [
      const Text('🎴 با ده، خال اعلامی را انتخاب کن', style: TextStyle(fontWeight: FontWeight.w800)),
      const SizedBox(height: 14),
      Row(children: [
        for (final e in kSuits.entries)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () {
                  Navigator.pop(context);
                  s.playCard(i, suit: e.key);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                      color: e.value.color.withOpacity(.14),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: e.value.color.withOpacity(.5))),
                  child: Column(children: [
                    Text(e.value.symbol, style: TextStyle(fontSize: 26, color: e.value.color)),
                    Text(e.value.fa, style: const TextStyle(fontSize: 11)),
                  ]),
                ),
              ),
            ),
          ),
      ]),
      const SizedBox(height: 10),
    ]));
  }

  Widget _tableArea(Map st, String gt, RoomSession s) {
    switch (gt) {
      case 'chahar_barg':
        final table = _l(_gf(st, 'table')).map(_m).toList();
        final last = _s(_gf(st, 'last_capturer'));
        return Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('روی میز', style: TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 10),
          if (table.isEmpty)
            const Text('— خالی —', style: TextStyle(color: Colors.white38, fontSize: 12))
          else
            Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center,
                children: [for (final c in table) PlayingCardView(card: c, width: 46, height: 66)]),
          if (last.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(14)),
              child: Text('آخرین جمع‌کننده: $last',
                  style: const TextStyle(fontSize: 10.5, color: Colors.white70)),
            ),
          ],
        ]);
      case 'haft_khabis':
        final top = _m(_gf(st, 'discard_top'));
        final dir = _i(_gf(st, 'direction'), 1);
        final pending = _i(_gf(st, 'pending_draw'));
        final declared = _s(_gf(st, 'declared_suit'));
        return Column(mainAxisSize: MainAxisSize.min, children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(dir == 1 ? Icons.rotate_right_rounded : Icons.rotate_left_rounded,
                color: PColors.gold, size: 20),
            const SizedBox(width: 6),
            Text(dir == 1 ? 'جهت: ساعتگرد' : 'جهت: پادساعتگرد',
                style: const TextStyle(fontSize: 11, color: Colors.white70)),
            if (pending > 0) ...[
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(color: PColors.red.withOpacity(.3),
                    borderRadius: BorderRadius.circular(12)),
                child: Text('🔥 جریمه: +${fa(pending)}',
                    style: const TextStyle(fontSize: 11, color: PColors.red)),
              ),
            ],
          ]),
          const SizedBox(height: 12),
          if (top.isEmpty || top.isEmpty)
            PlayingCardView.faceDown(width: 66, height: 94)
          else
            PlayingCardView(card: top, width: 66, height: 94),
          const SizedBox(height: 10),
          Text('دسته ریخته: ${fa(_i(_gf(st, 'discard_count')))} کارت',
              style: const TextStyle(fontSize: 10.5, color: Colors.white60)),
          if (declared.isNotEmpty && kSuits[declared] != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(14)),
                child: Text('خال اعلامی: ${kSuits[declared]!.symbol} ${kSuits[declared]!.fa}',
                    style: TextStyle(fontSize: 11.5, color: kSuits[declared]!.color)),
              ),
            ),
        ]);
      case 'shelem':
      case 'hokm':
        final phase = _s(_gf(st, 'phase'), 'playing');
        if (phase == 'bidding') {
          final bids = _m(_gf(st, 'bids'));
          final cur = _i(_gf(st, 'current_bid'));
          final win = _s(_gf(st, 'current_bid_winner'));
          return Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('💰 فاز مزایده', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            for (final p in _l(_gf(s.room, 'players')).map(_s))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(p == win ? '👑 $p' : p,
                      style: TextStyle(fontSize: 12,
                          color: p == win ? PColors.gold : Colors.white70)),
                  const SizedBox(width: 8),
                  Text(bids[p] == null ? 'پاس' : '${fa(bids[p])} امتیاز',
                      style: TextStyle(fontSize: 12,
                          color: bids[p] == null ? Colors.white38 : PColors.green)),
                ]),
              ),
            const SizedBox(height: 8),
            Text('پیشنهاد فعلی: ${cur == 0 ? '—' : fa(cur)}',
                style: const TextStyle(fontSize: 12, color: PColors.gold)),
          ]);
        }
        final trick = _l(_gf(st, 'trick'));
        final hokm = _s(_gf(st, 'hokm_suit'));
        final tricks = _m(_gf(st, 'tricks_won'));
        return Column(mainAxisSize: MainAxisSize.min, children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            if (hokm.isNotEmpty && kSuits[hokm] != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(14)),
                child: Text('حکم: ${kSuits[hokm]!.symbol} ${kSuits[hokm]!.fa}',
                    style: TextStyle(fontSize: 12, color: kSuits[hokm]!.color,
                        fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 10),
            ],
            Text('دست‌ها: ${fa(_i(_gf(tricks, 'team1')))} - ${fa(_i(_gf(tricks, 'team2')))}',
                style: const TextStyle(fontSize: 12, color: Colors.white70)),
          ]),
          const SizedBox(height: 14),
          if (trick.isEmpty)
            const Text('هنوز کارتی بازی نشده', style: TextStyle(color: Colors.white38, fontSize: 12))
          else
            Row(mainAxisSize: MainAxisSize.min, children: [
              for (final t in trick) ...[
                Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(_s(_l(t).isNotEmpty ? _l(t)[0] : ''),
                      style: const TextStyle(fontSize: 10, color: Colors.white70)),
                  const SizedBox(height: 3),
                  PlayingCardView(card: _m(_l(t).length > 1 ? _l(t)[1] : null), width: 46, height: 66),
                ]),
                const SizedBox(width: 8),
              ],
            ]),
          if (gt == 'shelem') ...[
            const SizedBox(height: 10),
            Text('امتیاز این دست: تیم۱ ${fa(_i(_gf(_m(_gf(st, 'round_scores')), 'team1')))}'
                ' — تیم۲ ${fa(_i(_gf(_m(_gf(st, 'round_scores')), 'team2')))}',
                style: const TextStyle(fontSize: 11, color: Colors.white60)),
          ],
        ]);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _bidPanel(RoomSession s, Map st) {
    final cur = _i(_gf(st, 'current_bid'));
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: PColors.panel, borderRadius: BorderRadius.circular(16),
          border: Border.all(color: PColors.blue.withOpacity(.4))),
      child: Row(children: [
        Expanded(
          child: TextField(
            controller: _bidCtrl,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontFamily: kFont, fontSize: 13),
            decoration: InputDecoration(
                hintText: cur > 0 ? 'بیشتر از ${fa(cur)} (تا ۱۶۵)' : '۱۰۰ تا ۱۶۵', isDense: true),
          ),
        ),
        const SizedBox(width: 8),
        GoldBtn(
          text: 'پیشنهاد',
          onPressed: () {
            final v = int.tryParse(_bidCtrl.text.trim());
            if (v == null || v < 100 || v > 165) {
              return toast('مقدار باید بین ۱۰۰ تا ۱۶۵ باشد', color: PColors.red);
            }
            if (v <= cur) return toast('باید بیشتر از پیشنهاد فعلی باشد', color: PColors.red);
            s.bid(v);
            _bidCtrl.clear();
          },
        ),
        const SizedBox(width: 8),
        GhostBtn(text: 'پاس', onPressed: () => s.bid(null)),
      ]),
    );
  }

  Widget _suitPicker(RoomSession s) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: PColors.panel, borderRadius: BorderRadius.circular(16),
          border: Border.all(color: PColors.gold.withOpacity(.5))),
      child: Column(children: [
        const Text('👑 شما حاکمی! حکم را انتخاب کن',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: PColors.gold)),
        const SizedBox(height: 8),
        Row(children: [
          for (final e in kSuits.entries)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => s.selectHokm(e.key),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                        color: e.value.color.withOpacity(.13),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: e.value.color.withOpacity(.5))),
                    child: Column(children: [
                      Text(e.value.symbol, style: TextStyle(fontSize: 22, color: e.value.color)),
                      Text(e.value.fa, style: const TextStyle(fontSize: 10.5)),
                    ]),
                  ),
                ),
              ),
            ),
        ]),
      ]),
    );
  }
}

class _ScoreBar extends StatelessWidget {
  final Map st;
  final String gt;
  final RoomSession s;
  const _ScoreBar({required this.st, required this.gt, required this.s});

  @override
  Widget build(BuildContext context) {
    final turn = _s(_gf(st, 'current_turn'));
    if (gt == 'shelem' || gt == 'hokm') {
      final teams = _m(_gf(st, 'teams'));
      final scores = _m(_gf(st, 'scores'));
      final t1 = _l(_gf(teams, 'team1')).map(_s).toList();
      final t2 = _l(_gf(teams, 'team2')).map(_s).toList();
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
        child: Row(children: [
          _teamBox('تیم ما', t1, _i(_gf(scores, 'team1')), turn, PColors.blue),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: PColors.panel, borderRadius: BorderRadius.circular(12)),
            child: const Text('VS', style: TextStyle(fontWeight: FontWeight.w900, color: PColors.gold)),
          ),
          const SizedBox(width: 8),
          _teamBox('تیم حریف', t2, _i(_gf(scores, 'team2')), turn, PColors.red),
        ]),
      );
    }
    final players = _l(_gf(st, 'players')).map(_s).toList();
    final scores = _m(_gf(st, 'scores'));
    final hands = _m(_gf(st, 'hand_counts'));
    return SizedBox(
      height: 46,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        children: [
          for (final p in players)
            Container(
              margin: const EdgeInsets.only(left: 7),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: turn == p ? PColors.gold.withOpacity(.2) : PColors.panel,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: turn == p ? PColors.gold : Colors.white10),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (turn == p) const Padding(padding: EdgeInsets.only(left: 4),
                    child: Text('▶', style: TextStyle(color: PColors.gold, fontSize: 10))),
                Text(p == s.me ? 'من' : p,
                    style: TextStyle(fontSize: 11.5,
                        color: p == s.me ? PColors.gold : PColors.text,
                        fontWeight: FontWeight.w700)),
                const SizedBox(width: 6),
                Text(
                  gt == 'chahar_barg' ? '🏅${fa(_i(_gf(scores, p)))}'
                      : '🂠${fa(_i(_gf(hands, p)))}',
                  style: const TextStyle(fontSize: 11),
                ),
              ]),
            ),
        ],
      ),
    );
  }

  Widget _teamBox(String title, List<String> members, int score, String turn, Color color) {
    final hasTurn = members.contains(turn);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(hasTurn ? .2 : .08),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: hasTurn ? PColors.gold : color.withOpacity(.4)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(title, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w800)),
            const Spacer(),
            Text(fa(score), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
          ]),
          Text(members.join(' و '),
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 9.5, color: PColors.sub)),
        ]),
      ),
    );
  }
}

class _TurnBar extends StatelessWidget {
  final Map st;
  final RoomSession s;
  final bool myTurn;
  const _TurnBar({required this.st, required this.s, required this.myTurn});

  @override
  Widget build(BuildContext context) {
    final turn = _s(_gf(st, 'current_turn'));
    final tl = _df(_gf(st, 'time_left'));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(children: [
        Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: myTurn ? PColors.gold.withOpacity(.2) : PColors.panel,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: myTurn ? PColors.gold : Colors.white10),
            ),
            child: Row(children: [
              Text(myTurn ? '🔥' : '⏳', style: const TextStyle(fontSize: 15)),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  turn.isEmpty ? '—' : (myTurn ? 'نوبت خودته!' : 'نوبت: $turn'),
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800,
                      color: myTurn ? PColors.gold : PColors.text),
                ),
              ),
            ]),
          ),
        ),
        const SizedBox(width: 10),
        TimerCircle(timeLeft: tl, total: s.turnTimeout),
        const SizedBox(width: 6),
        IconButton(
          tooltip: 'بازی خودکار',
          visualDensity: VisualDensity.compact,
          onPressed: myTurn ? s.autoPlay : null,
          icon: const Icon(Icons.smart_toy_outlined, size: 20),
        ),
        IconButton(
          tooltip: 'بروزرسانی وضعیت',
          visualDensity: VisualDensity.compact,
          onPressed: s.requestState,
          icon: const Icon(Icons.refresh_rounded, size: 20),
        ),
      ]),
    );
  }
}

class _HandArea extends StatelessWidget {
  final RoomSession s;
  final Map st;
  final bool myTurn, sorted;
  final int? selected;
  final VoidCallback onToggleSort;
  final void Function(int i, Map card) onCardTap;
  const _HandArea({
    required this.s, required this.st, required this.myTurn, required this.selected,
    required this.sorted, required this.onToggleSort, required this.onCardTap,
  });

  @override
  Widget build(BuildContext context) {
    if (!s.isPlayer) {
      return Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: PColors.panel, borderRadius: BorderRadius.circular(14)),
        child: const Center(child: Text('👁 شما تماشاچی هستید',
            style: TextStyle(color: PColors.sub, fontSize: 12.5))),
      );
    }
    final hand = _l(_gf(s.myState, 'hand')).map(_m).toList();
    if (sorted) {
      hand.sort((a, b) {
        final sa = kSuitOrder[_s(_gf(a, 'suit'))] ?? 9;
        final sb = kSuitOrder[_s(_gf(b, 'suit'))] ?? 9;
        if (sa != sb) return sa.compareTo(sb);
        return (kRankOrder[_s(_gf(a, 'rank'))] ?? 0).compareTo(kRankOrder[_s(_gf(b, 'rank'))] ?? 0);
      });
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Text('🃏 دست شما (${fa(hand.length)} کارت)',
              style: const TextStyle(fontSize: 11.5, color: PColors.sub)),
          const Spacer(),
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: onToggleSort,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(color: PColors.panel, borderRadius: BorderRadius.circular(10)),
              child: Row(children: [
                const Icon(Icons.sort_rounded, size: 13, color: PColors.gold),
                const SizedBox(width: 4),
                Text(sorted ? 'مرتب' : 'نامرتب', style: const TextStyle(fontSize: 10.5)),
              ]),
            ),
          ),
        ]),
        const SizedBox(height: 6),
        SizedBox(
          height: 104,
          child: hand.isEmpty
              ? const Center(child: Text('دست شما خالی است',
                  style: TextStyle(color: PColors.sub, fontSize: 12)))
              : ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  itemCount: hand.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 7),
                  itemBuilder: (c, i) => PlayingCardView(
                    card: hand[i], width: 56, height: 82,
                    selected: myTurn && selected == i,
                    dimmed: !myTurn,
                    onTap: myTurn ? () => onCardTap(i, hand[i]) : null,
                  ),
                ),
        ),
        if (myTurn)
          const Text('یک بار لمس = انتخاب، دوباره = بازی',
              style: TextStyle(fontSize: 10, color: PColors.sub)),
      ]),
    );
  }
}

class _ResultOverlay extends StatelessWidget {
  final Map st;
  final RoomSession s;
  final List<String> winners;
  final bool iWon;
  const _ResultOverlay({required this.st, required this.s, required this.winners, required this.iWon});

  @override
  Widget build(BuildContext context) {
    final meta = GameMeta.of(_s(_gf(s.room, 'game_type')));
    return Container(
      color: Colors.black.withOpacity(.6),
      child: Center(
        child: Glass(
          margin: const EdgeInsets.all(30),
          padding: const EdgeInsets.all(22),
          border: Border.all(color: iWon ? PColors.gold : Colors.white12, width: 1.5),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(iWon ? '🏆' : '😔', style: const TextStyle(fontSize: 54)),
            const SizedBox(height: 8),
            Text(iWon ? 'بردی! آفرین 🎉' : 'باختی... دفعه بعد میبری!',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900,
                    color: iWon ? PColors.gold : PColors.text)),
            const SizedBox(height: 8),
            if (winners.isNotEmpty)
              Text('برنده: ${winners.join('، ')}',
                  style: const TextStyle(fontSize: 12.5, color: PColors.sub)),
            const SizedBox(height: 6),
            Text('بازی ${meta.name} ${_s(_gf(s.room, 'name'))}',
                style: const TextStyle(fontSize: 11, color: PColors.sub)),
            const SizedBox(height: 18),
            GoldBtn(text: 'بازگشت به لابی', icon: Icons.meeting_room_outlined,
                onPressed: s.backToLobby),
            const SizedBox(height: 8),
            if (s.isHost)
              GoldBtn(
                text: '🔄 شروع دوباره', color: PColors.green,
                onPressed: () async {
                  try { await s.api.startGame(s.roomId); }
                  on ApiError catch (e) { toast(e.message, color: PColors.red); }
                },
              ),
          ]),
        ).animate().scale(begin: const Offset(.8, .8), end: const Offset(1, 1),
            duration: const Duration(milliseconds: 300), curve: Curves.easeOutBack),
      ),
    );
  }
}

// ---------------- چت و ایموجی (با پیام خصوصی و دستورات) ----------------
class ChatBar extends StatefulWidget {
  const ChatBar({super.key});
  @override
  State<ChatBar> createState() => _ChatBarState();
}

class _ChatBarState extends State<ChatBar> {
  final _ctrl = TextEditingController();
  DateTime _lastTyping = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  void _send(RoomSession s) {
    final t = _ctrl.text.trim();
    if (t.isEmpty) return;
    // دستور whisper: @username message
    if (t.startsWith('@')) {
      final spaceIdx = t.indexOf(' ');
      if (spaceIdx > 1) {
        final to = t.substring(1, spaceIdx);
        final msg = t.substring(spaceIdx + 1);
        s.sendChat(msg, to: to);
        _ctrl.clear();
        s.buzz(15, 40);
        return;
      }
    }
    s.sendChat(t);
    _ctrl.clear();
    s.buzz(15, 40);
  }

  void _showCommands(RoomSession s) {
    showSheet(context, Column(mainAxisSize: MainAxisSize.min, children: [
      const Text('💬 دستورات چت', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
      const SizedBox(height: 14),
      _cmdRow('/help', 'نمایش این لیست'),
      _cmdRow('/me <عمل>', 'انجام یک عمل (مثل /me خندید)'),
      _cmdRow('/whisper <user> <msg>', 'پیام خصوصی'),
      _cmdRow('@username <msg>', 'پیام خصوصی (میانبر)'),
      _cmdRow('/roll', 'انداختن تاس'),
      _cmdRow('/ready', 'آماده/ناآماده شدن'),
      _cmdRow('/start', 'شروع بازی (فقط میزبان)'),
      _cmdRow('/kick <user>', 'اخراج (فقط میزبان)'),
    ]));
  }

  Widget _cmdRow(String cmd, String desc) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: PColors.gold.withOpacity(.15),
              borderRadius: BorderRadius.circular(8)),
          child: Text(cmd, textDirection: ui.TextDirection.ltr,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: PColors.gold)),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(desc, style: const TextStyle(fontSize: 11.5))),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RoomSession>(builder: (context, s, _) {
      return Container(
        padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
        decoration: BoxDecoration(color: PColors.bg2,
            border: Border(top: BorderSide(color: Colors.white10))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (s.typing.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text('${s.typing.join('، ')} در حال نوشتن...',
                  style: const TextStyle(fontSize: 10, color: PColors.sub, fontStyle: FontStyle.italic)),
            ),
          Row(children: [
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.menu_book_outlined, size: 19, color: PColors.gold),
              onPressed: () => _showCommands(s),
            ),
            Expanded(
              child: TextField(
                controller: _ctrl,
                style: const TextStyle(fontFamily: kFont, fontSize: 13),
                decoration: const InputDecoration(
                  hintText: 'پیام یا @username...',
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                ),
                onChanged: (_) {
                  final now = DateTime.now();
                  if (now.difference(_lastTyping).inMilliseconds > 1500) {
                    _lastTyping = now;
                    s.sendTyping();
                  }
                },
                onSubmitted: (_) => _send(s),
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              borderRadius: BorderRadius.circular(13),
              onTap: () => _send(s),
              child: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [PColors.gold, PColors.goldDark]),
                    borderRadius: BorderRadius.circular(13)),
                child: const Icon(Icons.send_rounded, color: Colors.black, size: 20),
              ),
            ),
          ]),
        ]),
      );
    });
  }
}

class EmoteBar extends StatelessWidget {
  const EmoteBar({super.key});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<RoomSession>();
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        children: [
          for (final e in kEmotes)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => s.sendEmote(e),
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(color: PColors.panel, shape: BoxShape.circle,
                      border: Border.all(color: Colors.white10)),
                  child: Center(child: Text(e, style: const TextStyle(fontSize: 17))),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class EmoteOverlay extends StatelessWidget {
  const EmoteOverlay({super.key});
  @override
  Widget build(BuildContext context) {
    return Consumer<RoomSession>(builder: (context, s, _) {
      if (s.emotes.isEmpty) return const SizedBox.shrink();
      return Positioned(
        left: 14, bottom: 120,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (final e in s.emotes.take(5))
            Container(
              key: ValueKey(e['id']),
              margin: const EdgeInsets.only(bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: Colors.black.withOpacity(.55),
                  borderRadius: BorderRadius.circular(16)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text('${e['emoji']}', style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 5),
                Text('${e['username']}', style: const TextStyle(fontSize: 10.5, color: Colors.white70)),
              ]),
            ).animate().fadeIn(duration: 250.ms).slideX(begin: -.3, end: 0),
        ]),
      );
    });
  }
}

class ChatList extends StatefulWidget {
  final List<Map> messages;
  const ChatList({super.key, required this.messages});
  @override
  State<ChatList> createState() => _ChatListState();
}

class _ChatListState extends State<ChatList> {
  final _sc = ScrollController();

  @override
  void didUpdateWidget(covariant ChatList old) {
    super.didUpdateWidget(old);
    _jump();
  }

  void _jump() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_sc.hasClients) _sc.jumpTo(_sc.position.maxScrollExtent);
    });
  }

  @override
  void initState() { super.initState(); _jump(); }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: _sc,
      itemCount: widget.messages.length,
      itemBuilder: (c, i) {
        final m = widget.messages[i];
        final type = _s(_gf(m, 'type'));
        final txt = _s(_gf(m, 'message'));
        final user = _s(_gf(m, 'username'));
        final priv = _b(_gf(m, 'private'));
        final to = _s(_gf(m, 'to'));
        if (type == 'system') {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Text('— $txt —',
                  style: const TextStyle(fontSize: 10.5, color: PColors.sub, fontStyle: FontStyle.italic)),
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: RichText(
            text: TextSpan(
              style: const TextStyle(fontFamily: kFont, fontSize: 12, color: PColors.text),
              children: [
                if (priv) const TextSpan(text: '🔒 ', style: TextStyle(fontSize: 10)),
                TextSpan(text: '$user',
                    style: const TextStyle(color: PColors.gold, fontWeight: FontWeight.w700)),
                if (to.isNotEmpty)
                  TextSpan(text: ' → $to',
                      style: const TextStyle(color: PColors.blue, fontSize: 10)),
                const TextSpan(text: ': '),
                TextSpan(text: txt),
              ],
            ),
          ),
        );
      },
    );
  }
}

void showRoomHistory(BuildContext context, ApiService api, String roomId) {
  showSheet(context, FutureBuilder<Map<String, dynamic>>(
    future: api.gameHistory(roomId),
    builder: (context, snap) {
      return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('📜 تاریخچه بازی‌های اتاق',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
        const SizedBox(height: 12),
        if (!snap.hasData)
          const Padding(padding: EdgeInsets.all(20),
              child: Center(child: SpinKitFadingCircle(color: PColors.gold, size: 30)))
        else ...[
          for (final h in _l(_gf(snap.data, 'history')).map(_m)) ...[
            Glass(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              child: Row(children: [
                Text(GameMeta.of(_s(_gf(h, 'game_type'))).icon, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(GameMeta.of(_s(_gf(h, 'game_type'))).name,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                  Text('برنده: ${_l(_gf(h, 'winners')).map(_s).join('، ')}',
                      style: const TextStyle(fontSize: 11, color: PColors.sub)),
                ])),
                Text(timeAgo(_s(_gf(h, 'finished_at'))),
                    style: const TextStyle(fontSize: 10, color: PColors.sub)),
              ]),
            ),
          ],
          if (_l(_gf(snap.data, 'history')).isEmpty)
            const EmptyState(emoji: '🕰', title: 'هنوز بازی‌ای انجام نشده', sub: ''),
        ],
      ]);
    },
  ));
}

// ============================================================================
// 12) ویجت کارت بازی
// ============================================================================
class PlayingCardView extends StatelessWidget {
  final Map card;
  final double width, height;
  final bool selected, dimmed, faceDown;
  final VoidCallback? onTap;

  const PlayingCardView({
    super.key, required this.card, this.width = 56, this.height = 82,
    this.selected = false, this.dimmed = false, this.onTap,
  }) : faceDown = false;

  const PlayingCardView.faceDown({super.key, this.width = 56, this.height = 82})
      : card = const {}, selected = false, dimmed = false, faceDown = true, onTap = null;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: dimmed ? 0.45 : 1,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          transform: Matrix4.translationValues(0, selected ? -10 : 0, 0),
          width: width, height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(9),
            gradient: faceDown
                ? const LinearGradient(colors: [Color(0xFF22355E), Color(0xFF141F3C)])
                : const LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: [Color(0xFFFFFFFF), Color(0xFFE6EBF4)]),
            border: Border.all(
                color: selected ? PColors.gold : (faceDown ? PColors.goldDark.withOpacity(.4) : Colors.black26),
                width: selected ? 2.2 : 1),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(selected ? .5 : .3),
                  blurRadius: selected ? 14 : 7, offset: const Offset(0, 4)),
            ],
          ),
          child: faceDown
              ? Center(child: Text('🎴', style: TextStyle(fontSize: width * 0.4)))
              : Builder(builder: (_) {
                  final si = kSuits[_s(_gf(card, 'suit'))] ?? kSuits['spades']!;
                  final rank = _s(_gf(card, 'rank'));
                  return Padding(
                    padding: EdgeInsets.all(width * 0.09),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(rank, style: TextStyle(color: si.color,
                          fontWeight: FontWeight.w900, fontSize: width * 0.3, height: 1)),
                      Text(si.symbol, style: TextStyle(color: si.color, fontSize: width * 0.2)),
                      const Spacer(),
                      Center(child: Text(si.symbol,
                          style: TextStyle(color: si.color, fontSize: width * 0.48))),
                    ]),
                  );
                }),
        ),
      ),
    );
  }
}

class TimerCircle extends StatelessWidget {
  final double timeLeft;
  final int total;
  const TimerCircle({super.key, required this.timeLeft, required this.total});

  @override
  Widget build(BuildContext context) {
    final danger = timeLeft <= 5;
    return CircularPercentIndicator(
      radius: 23, lineWidth: 4.5,
      percent: total <= 0 ? 0 : (timeLeft / total).clamp(0.0, 1.0),
      center: Text('${math.max(0, timeLeft.ceil())}',
          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900,
              color: danger ? PColors.red : Colors.white)),
      progressColor: danger ? PColors.red : PColors.gold,
      backgroundColor: Colors.white12,
      circularStrokeCap: CircularStrokeCap.round,
    );
  }
}

// ============================================================================
// 13) رتبه‌بندی
// ============================================================================
class LeaderboardPage extends StatefulWidget {
  const LeaderboardPage({super.key});
  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage> {
  String? _game;
  List<Map> _rows = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final d = await context.read<AppState>().api.leaderboard(game: _game, limit: 50);
      if (!mounted) return;
      setState(() {
        _rows = _l(_gf(d, 'leaderboard')).map(_m).toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      SizedBox(
        height: 52,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          children: [
            _chip(null, '🌐 کل'),
            for (final g in GameMeta.all.values) _chip(g.type, '${g.icon} ${g.name}'),
          ],
        ),
      ),
      Expanded(
        child: _loading
            ? ListView(
                padding: const EdgeInsets.all(14),
                children: [
                  for (int i = 0; i < 6; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Shimmer.fromColors(
                        baseColor: Colors.white10, highlightColor: Colors.white24,
                        child: Container(height: 62, decoration: BoxDecoration(
                            color: Colors.white, borderRadius: BorderRadius.circular(18))),
                      ),
                    ),
                ],
              )
            : RefreshIndicator(
                onRefresh: _load, color: PColors.gold,
                child: _rows.isEmpty
                    ? ListView(children: const [
                        SizedBox(height: 100),
                        EmptyState(emoji: '🏜', title: 'هنوز کسی بازی نکرده', sub: 'اولین نفر باش!'),
                      ])
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(14, 4, 14, 20),
                        itemCount: _rows.length,
                        itemBuilder: (c, i) {
                          final r = _rows[i];
                          final wins = _i(_gf(r, 'wins'));
                          final played = _i(_gf(r, 'played'));
                          final rate = played == 0 ? 0.0 : wins / played;
                          final medal = i == 0 ? '🥇' : i == 1 ? '🥈' : i == 2 ? '🥉' : fa(i + 1);
                          return GestureDetector(
                            onTap: () => showUserProfile(context, _s(_gf(r, 'username'))),
                            child: Glass(
                              margin: const EdgeInsets.only(bottom: 9),
                              padding: const EdgeInsets.all(11),
                              border: i < 3 ? Border.all(color: PColors.gold.withOpacity(.5)) : null,
                              child: Row(children: [
                                SizedBox(width: 34, child: Text(medal,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900))),
                                AvatarView(emoji: _s(_gf(r, 'avatar'), '🙂'), size: 40),
                                const SizedBox(width: 10),
                                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(_s(_gf(r, 'username')),
                                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5,
                                          color: PColors.blue, decoration: TextDecoration.underline)),
                                  const SizedBox(height: 4),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: LinearProgressIndicator(
                                      value: rate, minHeight: 5,
                                      backgroundColor: Colors.white10,
                                      color: PColors.green,
                                    ),
                                  ),
                                ])),
                                const SizedBox(width: 10),
                                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                  Text('${fa(wins)} برد',
                                      style: const TextStyle(color: PColors.green,
                                          fontSize: 12, fontWeight: FontWeight.w800)),
                                  Text('${fa(played)} بازی',
                                      style: const TextStyle(color: PColors.sub, fontSize: 10.5)),
                                ]),
                              ]),
                            ),
                          );
                        },
                      ),
              ),
      ),
    ]);
  }

  Widget _chip(String? val, String label) {
    final sel = _game == val;
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: ChoiceChip(
        label: Text(label, style: TextStyle(fontFamily: kFont, fontSize: 12,
            color: sel ? Colors.black : PColors.text,
            fontWeight: sel ? FontWeight.w800 : FontWeight.normal)),
        selected: sel, selectedColor: PColors.gold,
        backgroundColor: PColors.panel,
        side: BorderSide(color: sel ? PColors.gold : Colors.white10),
        onSelected: (_) {
          setState(() => _game = val);
          _load();
        },
      ),
    );
  }
}

// ============================================================================
// 14) دوستان
// ============================================================================
class FriendsPage extends StatefulWidget {
  const FriendsPage({super.key});
  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage> with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 2, vsync: this);
  List<UserModel> _friends = [];
  List<UserModel> _requests = [];
  final _search = TextEditingController();
  List<UserModel> _results = [];
  bool _searching = false, _hasQuery = false;
  Timer? _deb;

  @override
  void initState() { super.initState(); _load(); }

  @override
  void dispose() {
    _tab.dispose(); _search.dispose(); _deb?.cancel(); super.dispose();
  }

  Future<void> _load() async {
    try {
      final d = await context.read<AppState>().api.friends();
      if (!mounted) return;
      setState(() {
        _friends = _l(_gf(d, 'friends')).map((e) => UserModel.from(_m(e))).toList();
        _requests = _l(_gf(d, 'requests')).map((e) => UserModel.from(_m(e))).toList();
      });
    } catch (_) {}
  }

  void _onSearch(String q) {
    _deb?.cancel();
    if (q.trim().isEmpty) {
      setState(() { _hasQuery = false; _results = []; });
      return;
    }
    _deb = Timer(const Duration(milliseconds: 500), () async {
      setState(() => _searching = true);
      try {
        final d = await context.read<AppState>().api.users(q: q.trim());
        if (!mounted) return;
        setState(() {
          _results = _l(_gf(d, 'users')).map((e) => UserModel.from(_m(e))).toList();
          _searching = false;
          _hasQuery = true;
        });
      } catch (_) {
        if (mounted) setState(() => _searching = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 6),
        child: TextField(
          controller: _search, style: const TextStyle(fontFamily: kFont),
          onChanged: _onSearch,
          decoration: InputDecoration(
            hintText: '🔍 جستجوی بازیکن برای دوستی...',
            isDense: true,
            suffixIcon: _hasQuery
                ? IconButton(icon: const Icon(Icons.close, size: 17),
                    onPressed: () {
                      _search.clear();
                      setState(() { _hasQuery = false; _results = []; });
                    })
                : null,
          ),
        ),
      ),
      if (_hasQuery)
        Expanded(
          child: _searching
              ? const Center(child: SpinKitFadingCircle(color: PColors.gold, size: 32))
              : ListView.builder(
                  padding: const EdgeInsets.all(14),
                  itemCount: _results.length,
                  itemBuilder: (c, i) => _userRow(app, _results[i], searchable: true),
                ),
        )
      else
        Expanded(
          child: Column(children: [
            TabBar(
              controller: _tab, labelColor: PColors.gold, unselectedLabelColor: PColors.sub,
              labelStyle: const TextStyle(fontFamily: kFont, fontWeight: FontWeight.w800),
              indicatorColor: PColors.gold,
              tabs: [
                Tab(text: 'دوستان (${fa(_friends.length)})'),
                Tab(text: 'درخواست‌ها (${fa(_requests.length)})'),
              ],
            ),
            Expanded(
              child: TabBarView(controller: _tab, children: [
                RefreshIndicator(
                  onRefresh: _load, color: PColors.gold,
                  child: _friends.isEmpty
                      ? ListView(children: const [
                          SizedBox(height: 80),
                          EmptyState(emoji: '🤝', title: 'هنوز دوستی نداری',
                              sub: 'از جستجوی بالا بازیکن پیدا کن'),
                        ])
                      : ListView.builder(
                          padding: const EdgeInsets.all(14),
                          itemCount: _friends.length,
                          itemBuilder: (c, i) => _userRow(app, _friends[i]),
                        ),
                ),
                RefreshIndicator(
                  onRefresh: _load, color: PColors.gold,
                  child: _requests.isEmpty
                      ? ListView(children: const [
                          SizedBox(height: 80),
                          EmptyState(emoji: '📭', title: 'درخواستی نداری', sub: ''),
                        ])
                      : ListView.builder(
                          padding: const EdgeInsets.all(14),
                          itemCount: _requests.length,
                          itemBuilder: (c, i) {
                            final u = _requests[i];
                            return Glass(
                              margin: const EdgeInsets.only(bottom: 9),
                              padding: const EdgeInsets.all(11),
                              child: Row(children: [
                                AvatarView(emoji: u.avatar, size: 40, online: u.online),
                                const SizedBox(width: 10),
                                Expanded(child: Text(u.username,
                                    style: const TextStyle(fontWeight: FontWeight.w700))),
                                GoldBtn(text: 'پذیرش', onPressed: () async {
                                  try {
                                    await app.api.friendAccept(u.username);
                                    toast('🎉 دوست شدید!', color: PColors.green);
                                    _load();
                                  } on ApiError catch (e) {
                                    toast(e.message, color: PColors.red);
                                  }
                                }),
                              ]),
                            );
                          },
                        ),
                ),
              ]),
            ),
          ]),
        ),
    ]);
  }

  Widget _userRow(AppState app, UserModel u, {bool searchable = false}) {
    final isFriend = _friends.any((f) => f.username == u.username);
    final isMe = u.username == app.me?.username;
    return Glass(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(11),
      child: Row(children: [
        AvatarView(emoji: u.avatar, size: 42, online: u.online),
        const SizedBox(width: 10),
        Expanded(
          child: GestureDetector(
            onTap: () => showUserProfile(context, u.username),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: Text(u.username, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5,
                        color: PColors.blue, decoration: TextDecoration.underline))),
                if (u.online)
                  const Padding(padding: EdgeInsets.only(right: 5),
                      child: Text('آنلاین', style: TextStyle(fontSize: 9.5, color: PColors.green))),
              ]),
              Text('${fa(u.wins)} برد • ${fa(u.friendsCount)} دوست',
                  style: const TextStyle(fontSize: 10.5, color: PColors.sub)),
            ]),
          ),
        ),
        if (!isMe)
          isFriend
              ? IconButton(
                  tooltip: 'حذف دوست',
                  icon: const Icon(Icons.person_remove_alt_1_outlined, size: 19, color: PColors.red),
                  onPressed: () async {
                    try {
                      await app.api.friendRemove(u.username);
                      toast('حذف شد'); _load();
                    } on ApiError catch (e) { toast(e.message, color: PColors.red); }
                  })
              : searchable
                  ? GoldBtn(text: '+ دوستی', onPressed: () async {
                      try {
                        await app.api.friendRequest(u.username);
                        toast('✅ درخواست ارسال شد', color: PColors.green);
                      } on ApiError catch (e) { toast(e.message, color: PColors.red); }
                    })
                  : const SizedBox.shrink(),
      ]),
    );
  }
}

// ============================================================================
// نمایش پروفایل دیگران
// ============================================================================
void showUserProfile(BuildContext context, String username) {
  final app = context.read<AppState>();
  if (app.me?.username == username) return; // خود کاربر است، به ProfilePage برود
  showSheet(context, FutureBuilder<Map<String, dynamic>>(
    future: app.api.userProfile(username),
    builder: (context, snap) {
      if (!snap.hasData) {
        return const Padding(padding: EdgeInsets.all(20),
            child: Center(child: SpinKitFadingCircle(color: PColors.gold, size: 30)));
      }
      if (snap.hasError) {
        return Padding(padding: const EdgeInsets.all(20),
            child: Text('❌ خطا: ${snap.error}', style: const TextStyle(color: PColors.red)));
      }
      final u = UserModel.from(_m(_gf(snap.data, 'user')));
      final perGame = _m(_gf(u.stats, 'per_game'));
      return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          AvatarView(emoji: u.avatar, size: 60, online: u.online),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(u.username, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            if (u.bio.isNotEmpty)
              Text(u.bio, style: const TextStyle(fontSize: 11.5, color: PColors.sub)),
            Text('عضویت: ${timeAgo(u.createdAt)}',
                style: const TextStyle(fontSize: 10, color: PColors.sub)),
          ])),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          _miniStat('🎮', fa(u.played)),
          const SizedBox(width: 6),
          _miniStat('🏆', fa(u.wins)),
          const SizedBox(width: 6),
          _miniStat('⚡', '${fa((u.winRate * 100).round())}٪'),
        ]),
        const SizedBox(height: 12),
        const Text('🕹 آمار هر بازی', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
        const SizedBox(height: 6),
        for (final g in GameMeta.all.values)
          Builder(builder: (_) {
            final pg = _m(_gf(perGame, g.type));
            final pl = _i(_gf(pg, 'played'));
            final w = _i(_gf(pg, 'wins'));
            if (pl == 0) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(children: [
                Text(g.icon, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Text(g.name, style: const TextStyle(fontSize: 12)),
                const Spacer(),
                Text('${fa(w)}/${fa(pl)}',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: PColors.gold)),
              ]),
            );
          }),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: GoldBtn(
              text: 'درخواست دوستی', icon: Icons.person_add_alt_1,
              onPressed: () async {
                try {
                  await app.api.friendRequest(u.username);
                  toast('✅ درخواست ارسال شد', color: PColors.green);
                } on ApiError catch (e) { toast(e.message, color: PColors.red); }
              },
            ),
          ),
        ]),
      ]);
    },
  ));
}

Widget _miniStat(String icon, String value) {
  return Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(color: PColors.bg1, borderRadius: BorderRadius.circular(10)),
      child: Column(children: [
        Text(icon, style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: PColors.gold)),
      ]),
    ),
  );
}

// ============================================================================
// 15) پروفایل
// ============================================================================
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final me = app.me;
    if (me == null) return const LoadingView();
    final perGame = _m(_gf(me.stats, 'per_game'));
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Glass(
          padding: const EdgeInsets.all(18),
          gradient: LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft,
              colors: [PColors.panel2, PColors.panel]),
          child: Row(children: [
            AvatarView(emoji: me.avatar, size: 66, online: true),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(me.username, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
              if (me.bio.isNotEmpty)
                Padding(padding: const EdgeInsets.only(top: 3),
                    child: Text(me.bio, style: const TextStyle(fontSize: 11.5, color: PColors.sub))),
              const SizedBox(height: 4),
              Row(children: [
                Text('💰 ${fa(app.coins)} سکه',
                    style: const TextStyle(fontSize: 11, color: PColors.gold)),
                const SizedBox(width: 10),
                Text('🔥 ${fa(app.dailyStreak)} روز',
                    style: const TextStyle(fontSize: 11, color: PColors.red)),
              ]),
            ])),
            IconButton(
              tooltip: 'ویرایش پروفایل',
              icon: const Icon(Icons.edit_rounded, color: PColors.gold),
              onPressed: () => showEditProfileSheet(context, app),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        Row(children: [
          _statBox('🎮', fa(me.played), 'بازی', PColors.blue),
          const SizedBox(width: 8),
          _statBox('🏆', fa(me.wins), 'برد', PColors.green),
          const SizedBox(width: 8),
          _statBox('😔', fa(me.losses), 'باخت', PColors.red),
          const SizedBox(width: 8),
          _statBox('⚡', '${fa((me.winRate * 100).round())}٪', 'درصد برد', PColors.gold),
        ]),
        const SizedBox(height: 12),
        const Text('🕹 آمار هر بازی', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
        const SizedBox(height: 8),
        for (final g in GameMeta.all.values) ...[
          Builder(builder: (_) {
            final pg = _m(_gf(perGame, g.type));
            final pl = _i(_gf(pg, 'played'));
            final w = _i(_gf(pg, 'wins'));
            return Glass(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(11),
              child: Row(children: [
                Text(g.icon, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(g.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                        value: pl == 0 ? 0 : w / pl, minHeight: 5,
                        backgroundColor: Colors.white10, color: g.color),
                  ),
                ])),
                const SizedBox(width: 10),
                Text('${fa(w)}/${fa(pl)}',
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: PColors.gold)),
              ]),
            );
          }),
        ],
        const SizedBox(height: 6),
        _menuTile(context, Icons.card_giftcard, 'پاداش روزانه',
            badge: app.canClaimDaily() ? '!' : '',
            onTap: () => showDailyRewardSheet(context)),
        _menuTile(context, Icons.emoji_events_outlined, 'دستاوردها',
            badge: '${fa(me.achievements.length)}',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AchievementsPage()))),
        _menuTile(context, Icons.notifications_outlined, 'اعلان‌ها',
            badge: app.notifications.isEmpty ? '' : fa(app.notifications.length),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsPage()))),
        _menuTile(context, Icons.settings_outlined, 'تنظیمات',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage()))),
        _menuTile(context, Icons.info_outline_rounded, 'درباره پاسور', onTap: () => showAboutSheet(context)),
        const SizedBox(height: 8),
        GhostBtn(text: '🚪 خروج از حساب', color: PColors.red, onPressed: () async {
          final ok = await confirmDialog(context, 'خروج', 'از حساب خارج می‌شوی. مطمئنی؟', ok: 'خروج');
          if (!ok) return;
          await app.logout();
          if (context.mounted) {
            Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const AuthPage()), (_) => false);
          }
        }),
      ],
    );
  }

  Widget _statBox(String emoji, String value, String label, Color color) {
    return Expanded(
      child: Glass(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(children: [
          Text(emoji, style: const TextStyle(fontSize: 19)),
          const SizedBox(height: 3),
          Text(value, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: color)),
          Text(label, style: const TextStyle(fontSize: 9.5, color: PColors.sub)),
        ]),
      ),
    );
  }

  Widget _menuTile(BuildContext context, IconData icon, String title,
      {String badge = '', VoidCallback? onTap}) {
    return Glass(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(icon, color: PColors.gold, size: 21),
        title: Text(title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          if (badge.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: PColors.gold.withOpacity(.18),
                  borderRadius: BorderRadius.circular(12)),
              child: Text(badge, style: const TextStyle(fontSize: 10.5, color: PColors.gold)),
            ),
          const Icon(Icons.chevron_left_rounded, size: 19, color: PColors.sub),
        ]),
        onTap: onTap,
      ),
    );
  }
}

void showEditProfileSheet(BuildContext context, AppState app) {
  final bio = TextEditingController(text: app.me?.bio ?? '');
  String avatar = app.me?.avatar ?? '🙂';
  showSheet(context, StatefulBuilder(builder: (ctx, setSt) {
    return SingleChildScrollView(
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('✏️ ویرایش پروفایل',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
        const SizedBox(height: 14),
        Center(child: AvatarView(emoji: avatar, size: 70)),
        const SizedBox(height: 12),
        Wrap(spacing: 7, runSpacing: 7, alignment: WrapAlignment.center, children: [
          for (final e in kAvatars)
            GestureDetector(
              onTap: () => setSt(() => avatar = e),
              child: Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  color: avatar == e ? PColors.gold.withOpacity(.25) : PColors.bg1,
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: avatar == e ? PColors.gold : Colors.white10),
                ),
                child: Center(child: Text(e, style: const TextStyle(fontSize: 19))),
              ),
            ),
        ]),
        const SizedBox(height: 14),
        TextField(controller: bio, style: const TextStyle(fontFamily: kFont), maxLength: 200,
            decoration: const InputDecoration(hintText: 'بیو', counterText: '')),
        const SizedBox(height: 12),
        GoldBtn(text: 'ذخیره', icon: Icons.save_outlined, onPressed: () async {
          try {
            await app.api.updateProfile({'avatar': avatar, 'bio': bio.text.trim()});
            await app.refreshMe();
            if (ctx.mounted) Navigator.pop(ctx);
            toast('✅ ذخیره شد', color: PColors.green);
          } on ApiError catch (e) {
            toast(e.message, color: PColors.red);
          }
        }),
      ]),
    );
  }));
}

void showAboutSheet(BuildContext context) {
  showSheet(context, Column(mainAxisSize: MainAxisSize.min, children: [
    const Text('🎴', style: TextStyle(fontSize: 44)),
    const Text('پاسور', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: PColors.gold)),
    Text('نسخه $kAppVersion', style: const TextStyle(color: PColors.sub, fontSize: 12)),
    const SizedBox(height: 10),
    const Text('سرور پیشرفته بازی‌های پاسور ایرانی', style: TextStyle(fontSize: 13)),
    const Text('چهاربرگ • هفت خبیث • شلم • حکم',
        style: TextStyle(fontSize: 11.5, color: PColors.sub)),
    const SizedBox(height: 14),
    GoldBtn(text: 'مستندات سرور (Swagger)', icon: Icons.description_outlined, onPressed: () async {
      final app = context.read<AppState>();
      final u = Uri.parse('${app.api.baseUrl}/docs');
      if (await canLaunchUrl(u)) await launchUrl(u, mode: LaunchMode.externalApplication);
    }),
    const SizedBox(height: 8),
    const Text('ساخته شده با ❤️ برای پاسوربازها',
        style: TextStyle(fontSize: 11, color: PColors.sub)),
  ]));
}

// ============================================================================
// 16) دستاوردها
// ============================================================================
class AchievementsPage extends StatelessWidget {
  const AchievementsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final defs = app.achDefs.isEmpty ? _fallbackAch() : app.achDefs;
    final mine = app.me?.achievements.map(_s).toSet() ?? <String>{};
    return Scaffold(
      appBar: AppBar(title: const Text('🏅 دستاوردها')),
      body: GridView.builder(
        padding: const EdgeInsets.all(14),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.05),
        itemCount: defs.length,
        itemBuilder: (c, i) {
          final key = defs.keys.elementAt(i);
          final info = _m(defs[key]);
          final unlocked = mine.contains(key.toString().trim());
          return Glass(
            padding: const EdgeInsets.all(13),
            gradient: unlocked ? LinearGradient(colors: [PColors.gold.withOpacity(.16), PColors.panel]) : null,
            border: unlocked ? Border.all(color: PColors.gold.withOpacity(.55)) : null,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(unlocked ? '🏅' : '🔒', style: const TextStyle(fontSize: 22)),
                const Spacer(),
                if (unlocked) const Icon(Icons.check_circle, color: PColors.green, size: 17),
              ]),
              const SizedBox(height: 6),
              Text(_s(_gf(info, 'title')),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5,
                      color: unlocked ? PColors.gold : PColors.sub)),
              const SizedBox(height: 3),
              Text(_s(_gf(info, 'desc')), maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10.5, color: PColors.sub)),
            ]),
          );
        },
      ),
    );
  }

  Map _fallbackAch() => {
        'first_win': {'title': '🏆 اولین پیروزی', 'desc': 'اولین بازی خودت را ببر'},
        'chahar_master': {'title': '🎯 استاد چهاربرگ', 'desc': '۱۰ بازی چهاربرگ ببر'},
        'hokm_king': {'title': '👑 پادشاه حکم', 'desc': '۱۰ بازی حکم ببر'},
        'shelem_pro': {'title': '💎 حرفه‌ای شلم', 'desc': '۱۰ بازی شلم ببر'},
        'haft_champ': {'title': '🎴 قهرمان هفت خبیث', 'desc': '۱۰ بازی هفت خبیث ببر'},
        'social': {'title': '🤝 اجتماعی', 'desc': '۵ دوست اضافه کن'},
        'chatty': {'title': '💬 پرحرف', 'desc': '۱۰۰ پیام چت بفرست'},
        'veteran': {'title': '🎖 کهنه‌کار', 'desc': '۵۰ بازی انجام بده'},
      };
}

// ============================================================================
// 17) اعلان‌ها
// ============================================================================
class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('🔔 اعلان‌ها'),
        actions: [
          if (app.notifications.isNotEmpty)
            TextButton(
              onPressed: app.markAllRead,
              child: const Text('خواندن همه', style: TextStyle(color: PColors.gold, fontSize: 12)),
            ),
        ],
      ),
      body: app.notifications.isEmpty
          ? const EmptyState(emoji: '🔕', title: 'اعلانی نداری', sub: 'نتایج بازی‌ها اینجا می‌آید')
          : ListView.builder(
              padding: const EdgeInsets.all(14),
              itemCount: app.notifications.length,
              itemBuilder: (c, i) {
                final n = app.notifications[app.notifications.length - 1 - i];
                final won = _b(_gf(n, 'won'));
                final type = _s(_gf(n, 'type'));
                final icon = type == 'game_result'
                    ? (won ? '🏆' : '🎮')
                    : type == 'friend_request' ? '🤝' : '📣';
                return Glass(
                  margin: const EdgeInsets.only(bottom: 9),
                  padding: const EdgeInsets.all(12),
                  child: Row(children: [
                    Text(icon, style: const TextStyle(fontSize: 24)),
                    const SizedBox(width: 11),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(_s(_gf(n, 'title'), 'اعلان'),
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                      const SizedBox(height: 2),
                      Text(_s(_gf(n, 'body')),
                          style: const TextStyle(fontSize: 11.5, color: PColors.sub)),
                    ])),
                    Text(timeAgo(_s(_gf(n, 'timestamp'))),
                        style: const TextStyle(fontSize: 10, color: PColors.sub)),
                  ]),
                );
              },
            ),
    );
  }
}

// ============================================================================
// 18) تنظیمات (با تم تیره/روشن)
// ============================================================================
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(title: const Text('⚙️ تنظیمات')),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Glass(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('🌐 اتصال', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
              const SizedBox(height: 8),
              Row(children: [
                Container(width: 9, height: 9, decoration: BoxDecoration(
                    shape: BoxShape.circle, color: app.serverOk ? PColors.green : PColors.red)),
                const SizedBox(width: 6),
                Text(app.serverOk ? 'متصل • پینگ ${fa(app.pingMs)}ms' : 'قطع',
                    style: TextStyle(fontSize: 12,
                        color: app.serverOk ? PColors.green : PColors.red)),
                const Spacer(),
                GhostBtn(text: 'تست', onPressed: () async {
                  await app.ping();
                  toast(app.serverOk ? '✅ سرور آنلاین' : '❌ آفلاین',
                      color: app.serverOk ? PColors.green : PColors.red);
                }),
              ]),
              const SizedBox(height: 8),
              Text(app.api.baseUrl.isEmpty ? 'آدرسی تنظیم نشده' : app.api.baseUrl,
                  textDirection: ui.TextDirection.ltr,
                  style: const TextStyle(fontSize: 10.5, color: PColors.sub)),
              const SizedBox(height: 8),
              GoldBtn(text: '⚙️ مدیریت آدرس سرور و API Key',
                  onPressed: () => showConnectionSheet(context, app)),
            ]),
          ),
          const SizedBox(height: 12),
          Glass(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Column(children: [
              SwitchListTile(
                value: app.darkMode,
                onChanged: (v) => app.setDarkMode(v),
                title: const Text('حالت تاریک', style: TextStyle(fontSize: 13.5)),
                subtitle: const Text('تم تیره/روشن اپلیکیشن', style: TextStyle(fontSize: 11)),
                secondary: Icon(app.darkMode ? Icons.dark_mode : Icons.light_mode,
                    size: 21, color: PColors.gold),
              ),
              SwitchListTile(
                value: app.haptics,
                onChanged: (v) async {
                  app.haptics = v;
                  await app.api.prefs.setBool('haptics', v);
                  app.notifyListeners();
                  if (v) app.buzz(30);
                },
                title: const Text('لرزش (هپتیک)', style: TextStyle(fontSize: 13.5)),
                subtitle: const Text('بازخورد لمسی هنگام بازی', style: TextStyle(fontSize: 11)),
                secondary: const Icon(Icons.vibration_rounded, size: 21, color: PColors.gold),
              ),
              SwitchListTile(
                value: app.soundOn,
                onChanged: (v) async {
                  app.soundOn = v;
                  await app.api.prefs.setBool('sound', v);
                  app.notifyListeners();
                },
                title: const Text('صدا', style: TextStyle(fontSize: 13.5)),
                subtitle: const Text('افکت‌های صوتی بازی (در توسعه)', style: TextStyle(fontSize: 11)),
                secondary: const Icon(Icons.volume_up_rounded, size: 21, color: PColors.gold),
              ),
              SwitchListTile(
                value: app.notifOn,
                onChanged: (v) async {
                  app.notifOn = v;
                  await app.api.prefs.setBool('notif', v);
                  app.notifyListeners();
                },
                title: const Text('اعلان‌ها', style: TextStyle(fontSize: 13.5)),
                subtitle: const Text('نتایج بازی، دوستی و دستاوردها', style: TextStyle(fontSize: 11)),
                secondary: const Icon(Icons.notifications_active_outlined, size: 21, color: PColors.gold),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          Glass(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('👤 حساب', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
              const SizedBox(height: 6),
              Text('کاربر: ${app.me?.username ?? '-'}', style: const TextStyle(fontSize: 12.5)),
              const SizedBox(height: 10),
              GhostBtn(text: '🚪 خروج از حساب', color: PColors.red, onPressed: () async {
                final ok = await confirmDialog(context, 'خروج', 'مطمئنی می‌خواهی خارج شوی؟', ok: 'خروج');
                if (!ok) return;
                await app.logout();
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const AuthPage()), (_) => false);
                }
              }),
            ]),
          ),
          const SizedBox(height: 12),
          Center(child: Text('پاسور v$kAppVersion 🎴',
              style: const TextStyle(fontSize: 11, color: PColors.sub))),
        ],
      ),
    );
  }
}

// ============================================================================
// 19) ویجت‌های عمومی
// ============================================================================
class Glass extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding, margin;
  final double radius;
  final Color? color;
  final Gradient? gradient;
  final BoxBorder? border;
  const Glass({
    super.key, required this.child,
    this.padding = const EdgeInsets.all(16), this.margin = EdgeInsets.zero,
    this.radius = 20, this.color = PColors.panel, this.gradient, this.border,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin, padding: padding,
      decoration: BoxDecoration(
        color: gradient == null ? color : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(radius),
        border: border ?? Border.all(color: Colors.white10),
      ),
      child: child,
    );
  }
}

class GoldBtn extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final Color? color;
  const GoldBtn({super.key, required this.text, this.onPressed, this.icon, this.loading = false, this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity, height: 48,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color ?? PColors.gold,
          foregroundColor: color == PColors.panel2 ? PColors.sub : Colors.black,
          disabledBackgroundColor: PColors.panel2,
          disabledForegroundColor: PColors.sub,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontFamily: kFont, fontSize: 14, fontWeight: FontWeight.w800),
        ),
        onPressed: loading ? null : onPressed,
        child: loading
            ? const SizedBox(width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.black54))
            : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                if (icon != null) Icon(icon, size: 18),
                if (icon != null) const SizedBox(width: 7),
                Flexible(child: Text(text, overflow: TextOverflow.ellipsis)),
              ]),
      ),
    );
  }
}

class GhostBtn extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? color;
  const GhostBtn({super.key, required this.text, this.onPressed, this.icon, this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: color ?? PColors.text,
          side: BorderSide(color: (color ?? PColors.gold).withOpacity(.5)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
          textStyle: const TextStyle(fontFamily: kFont, fontSize: 12.5, fontWeight: FontWeight.w700),
        ),
        onPressed: onPressed,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) Icon(icon, size: 16),
          if (icon != null) const SizedBox(width: 5),
          Text(text),
        ]),
      ),
    );
  }
}

class InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const InfoChip({super.key, required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: Colors.white.withOpacity(.05),
          borderRadius: BorderRadius.circular(12)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: PColors.gold),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10.5)),
      ]),
    );
  }
}

class AvatarView extends StatelessWidget {
  final String emoji;
  final double size;
  final bool? online;
  const AvatarView({super.key, required this.emoji, this.size = 44, this.online});

  static const _gradients = [
    [Color(0xFF3A6073), Color(0xFF16222A)],
    [Color(0xFF614385), Color(0xFF516395)],
    [Color(0xFF11998E), Color(0xFF38EF7D)],
    [Color(0xFFFC466B), Color(0xFF3F5EFB)],
    [Color(0xFFC99A2E), Color(0xFF8A6D1D)],
    [Color(0xFF232526), Color(0xFF414345)],
  ];

  @override
  Widget build(BuildContext context) {
    final g = _gradients[emoji.hashCode.abs() % _gradients.length];
    return Stack(clipBehavior: Clip.none, children: [
      Container(
        width: size, height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: g),
          border: Border.all(color: Colors.white24),
        ),
        child: Center(child: Text(emoji, style: TextStyle(fontSize: size * 0.5))),
      ),
      if (online != null)
        Positioned(
          bottom: 0, left: 0,
          child: Container(
            width: size * 0.26, height: size * 0.26,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: online! ? PColors.green : const Color(0xFF5A6478),
              border: Border.all(color: PColors.bg1, width: 2),
            ),
          ),
        ),
    ]);
  }
}

class EmptyState extends StatelessWidget {
  final String emoji, title, sub;
  const EmptyState({super.key, required this.emoji, required this.title, this.sub = ''});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(emoji, style: const TextStyle(fontSize: 54)),
        const SizedBox(height: 10),
        Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
        if (sub.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(sub, style: const TextStyle(color: PColors.sub, fontSize: 12)),
        ],
      ]),
    );
  }
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});
  @override
  Widget build(BuildContext context) {
    return const Center(child: SpinKitFadingCircle(color: PColors.gold, size: 42));
  }
}