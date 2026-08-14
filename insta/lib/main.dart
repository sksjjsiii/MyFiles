// main.dart
// ═══════════════════════════════════════════════════════════════
//  NOKHODX v4.2.0
//
//  - Status bar: Light => BLACK, Dark => WHITE, everywhere
//  - Home media corners rounded like initial version
//  - Story row: shows story owners, ring only for unseen
//  - After viewing story: avatar remains, ring clears
//  - Reels: fit (contain), not stretched/cropped
//  - Avatar tap opens unseen story if available
//  - DM swipe-to-reply: own message left, other message right
//  - @ mention autocomplete in composer
//  - Audio download button next to play, hidden after complete
//  - DM can send image/video/audio/file
//  - Text-only post fixed
//  - Latest avatar is default avatar
// ═══════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_view/photo_view.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import 'package:video_player/video_player.dart';

// ═══════════════════════════════ MAIN ═══════════════════════════
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await ApiClient.instance.init();
  await ThemeStore.instance.load();
  await FileCache.instance.init();

  applySystemUIStyle(ThemeStore.instance.isDark);

  runApp(const NokhodXApp());
}

void applySystemUIStyle(bool isDark) {
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
    statusBarColor: isDark ? Colors.white : Colors.black,
    statusBarIconBrightness: isDark ? Brightness.dark : Brightness.light,
    statusBarBrightness: isDark ? Brightness.light : Brightness.dark,
    systemNavigationBarColor: isDark ? Colors.black : Colors.white,
    systemNavigationBarIconBrightness:
        isDark ? Brightness.light : Brightness.dark,
  ));

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
}

class NokhodXApp extends StatelessWidget {
  const NokhodXApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState()),
        ChangeNotifierProvider.value(value: ThemeStore.instance),
        ChangeNotifierProvider.value(value: AudioController.instance),
        ChangeNotifierProvider.value(value: FileCache.instance),
      ],
      child: Consumer<ThemeStore>(
        builder: (context, theme, _) {
          final isDark = theme.isDark;
          final p = Pal(isDark: isDark);

          final overlay = SystemUiOverlayStyle(
            statusBarColor: isDark ? Colors.white : Colors.black,
            statusBarIconBrightness:
                isDark ? Brightness.dark : Brightness.light,
            statusBarBrightness:
                isDark ? Brightness.light : Brightness.dark,
            systemNavigationBarColor: isDark ? Colors.black : Colors.white,
            systemNavigationBarIconBrightness:
                isDark ? Brightness.light : Brightness.dark,
          );

          return MaterialApp(
            title: 'NokhodX',
            debugShowCheckedModeBanner: false,
            builder: (context, child) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                SystemChrome.setSystemUIOverlayStyle(overlay);
                SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
              });

              return AnnotatedRegion<SystemUiOverlayStyle>(
                value: overlay,
                child: child ?? const SizedBox.shrink(),
              );
            },
            theme: ThemeData(
              useMaterial3: true,
              brightness: isDark ? Brightness.dark : Brightness.light,
              scaffoldBackgroundColor: p.bg,
              colorScheme: ColorScheme(
                brightness: isDark ? Brightness.dark : Brightness.light,
                primary: p.accent,
                onPrimary: Colors.white,
                secondary: p.purple,
                onSecondary: Colors.white,
                surface: p.surface,
                onSurface: p.text,
                error: p.red,
                onError: Colors.white,
              ),
              textTheme: GoogleFonts.interTextTheme(
                (isDark ? ThemeData.dark() : ThemeData.light()).textTheme,
              ),
              appBarTheme: AppBarTheme(
                backgroundColor: Colors.transparent,
                elevation: 0,
                surfaceTintColor: Colors.transparent,
                iconTheme: IconThemeData(color: p.text),
              ),
              dividerColor: p.border,
            ),
            home: const BootWrapper(),
          );
        },
      ),
    );
  }
}

class BootWrapper extends StatefulWidget {
  const BootWrapper({super.key});

  @override
  State<BootWrapper> createState() => _BootWrapperState();
}

class _BootWrapperState extends State<BootWrapper> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      applySystemUIStyle(ThemeStore.instance.isDark);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeStore>(
      builder: (context, theme, child) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          applySystemUIStyle(theme.isDark);
        });
        return child!;
      },
      child: const SplashScreen(),
    );
  }
}

void _applyBars(BuildContext context) {
  final isDark = context.read<ThemeStore>().isDark;
  applySystemUIStyle(isDark);
}

// ═══════════════════════════════ STORES ═══════════════════════════
class ThemeStore extends ChangeNotifier {
  ThemeStore._();
  static final ThemeStore instance = ThemeStore._();

  bool _isDark = true;
  bool get isDark => _isDark;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _isDark = prefs.getBool('nokh_theme_dark') ?? true;
    notifyListeners();
  }

  Future<void> toggle() async {
    _isDark = !_isDark;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('nokh_theme_dark', _isDark);
  }
}

// ═══════════════════════════════ PALETTE ═══════════════════════════
class Pal {
  final bool isDark;
  Pal({required this.isDark});

  Color get bg => isDark ? const Color(0xFF070B10) : const Color(0xFFF6F8FB);
  Color get surface =>
      isDark ? const Color(0xFF0E141B) : const Color(0xFFFFFFFF);
  Color get card => isDark ? const Color(0xFF131B24) : const Color(0xFFF1F4F8);
  Color get card2 =>
      isDark ? const Color(0xFF1A2532) : const Color(0xFFE6ECF2);
  Color get border =>
      isDark ? const Color(0xFF1F2B38) : const Color(0xFFD9E1EA);
  Color get text => isDark ? const Color(0xFFEAF0F6) : const Color(0xFF0A1420);
  Color get sub => isDark ? const Color(0xFF8CA0B3) : const Color(0xFF5B6B7E);
  Color get accent => const Color(0xFF1D9BF0);
  Color get pink => const Color(0xFFF91880);
  Color get green => const Color(0xFF00BA7C);
  Color get purple => const Color(0xFF7856FF);
  Color get orange => const Color(0xFFFF7A00);
  Color get gold => const Color(0xFFFFD400);
  Color get red => const Color(0xFFE0245E);

  LinearGradient get brand => LinearGradient(
        colors: [accent, purple],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  LinearGradient get reel => LinearGradient(
        colors: [pink, orange],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
}

Pal _p(BuildContext context) {
  try {
    return Pal(isDark: context.watch<ThemeStore>().isDark);
  } catch (_) {
    return Pal(isDark: true);
  }
}

// ═══════════════════════════════ AUDIO CONTROLLER ══════════════════
class AudioController extends ChangeNotifier {
  AudioController._();
  static final AudioController instance = AudioController._();

  final AudioPlayer _player = AudioPlayer();

  String? _currentSource;
  String? _currentKey;
  String? _currentTitle;
  String? _currentArtist;
  double? _currentDuration;
  double _position = 0;
  bool _playing = false;
  bool _muted = false;
  Timer? _posTimer;

  String? get currentSource => _currentSource;
  String? get currentKey => _currentKey;
  String? get currentTitle => _currentTitle;
  String? get currentArtist => _currentArtist;
  double? get currentDuration => _currentDuration;
  double get position => _position;
  bool get playing => _playing && !_muted;
  bool get hasTrack => _currentKey != null;
  bool get muted => _muted;

  Source _makeSource(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return UrlSource(path);
    }
    return DeviceFileSource(path);
  }

  Future<void> play(
    String source, {
    String? key,
    String? title,
    String? artist,
    double? duration,
  }) async {
    final k = key ?? source;

    if (_currentKey == k && _playing) {
      await pause();
      return;
    }

    if (_currentKey == k && !_playing) {
      await resume();
      return;
    }

    _currentSource = source;
    _currentKey = k;
    _currentTitle = title;
    _currentArtist = artist;
    _currentDuration = duration;
    _position = 0;

    await _player.stop();
    _posTimer?.cancel();

    await _player.play(_makeSource(source));
    _playing = true;
    _muted = false;

    _posTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (_playing && !_muted) {
        _position += 0.5;

        if (_currentDuration != null && _position >= _currentDuration!) {
          _position = 0;
          _playing = false;
          _posTimer?.cancel();
        }

        notifyListeners();
      }
    });

    notifyListeners();
  }

  Future<void> pause() async {
    await _player.pause();
    _playing = false;
    notifyListeners();
  }

  Future<void> resume() async {
    if (_currentKey == null) return;

    await _player.resume();
    _playing = true;
    notifyListeners();
  }

  Future<void> seekTo(double seconds) async {
    _position = seconds;
    await _player.seek(Duration(milliseconds: (seconds * 1000).toInt()));
    notifyListeners();
  }

  Future<void> stop() async {
    await _player.stop();
    _playing = false;
    _posTimer?.cancel();

    _currentSource = null;
    _currentKey = null;
    _currentTitle = null;
    _currentArtist = null;
    _currentDuration = null;
    _position = 0;

    notifyListeners();
  }

  void muteTemporarily() {
    if (!_muted && _playing) {
      _muted = true;
      _player.setVolume(0);
      notifyListeners();
    }
  }

  void unmute() {
    if (_muted) {
      _muted = false;
      _player.setVolume(1);
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _posTimer?.cancel();
    _player.dispose();
    super.dispose();
  }
}

// ═══════════════════════════════ FILE CACHE ═══════════════════════
class FileCache extends ChangeNotifier {
  FileCache._();
  static final FileCache instance = FileCache._();

  Directory? _cacheDir;

  final Map<String, double> _downloadProgress = {};
  final Map<String, bool> _activeDownloads = {};
  final http.Client _client = http.Client();

  Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    _cacheDir = Directory('${dir.path}/NokhodXCache');

    if (!await _cacheDir!.exists()) {
      await _cacheDir!.create(recursive: true);
    }
  }

  String _hashUrl(String url) {
    final bytes = utf8.encode(url);
    int hash = 0;

    for (final b in bytes) {
      hash = (hash * 31 + b) & 0x7fffffff;
    }

    final clean = url.split('?').first;
    final ext = clean.contains('.') ? '.${clean.split('.').last}' : '';

    return '${hash.toRadixString(16)}$ext';
  }

  String getLocalPath(String url) => '${_cacheDir!.path}/${_hashUrl(url)}';

  Future<bool> hasFile(String url) async {
    final f = File(getLocalPath(url));
    return await f.exists();
  }

  double getProgress(String url) => _downloadProgress[url] ?? 0;
  bool isDownloading(String url) => _activeDownloads[url] ?? false;

  Future<String> downloadWithResume(
    String url, {
    void Function(double progress)? onProgress,
    Map<String, String>? headers,
  }) async {
    final localPath = getLocalPath(url);
    final file = File(localPath);

    if (await file.exists()) {
      try {
        final headReq = http.Request('HEAD', Uri.parse(url));
        if (headers != null) headReq.headers.addAll(headers);

        final headRes = await _client
            .send(headReq)
            .timeout(const Duration(seconds: 10));

        final remoteSize =
            int.tryParse(headRes.headers['content-length'] ?? '') ?? 0;
        final localSize = await file.length();

        if (remoteSize > 0 && localSize == remoteSize) {
          _downloadProgress[url] = 1.0;
          notifyListeners();
          onProgress?.call(1.0);
          return localPath;
        }

        if (remoteSize == 0 && localSize > 0) {
          _downloadProgress[url] = 1.0;
          notifyListeners();
          onProgress?.call(1.0);
          return localPath;
        }
      } catch (_) {
        _downloadProgress[url] = 1.0;
        notifyListeners();
        onProgress?.call(1.0);
        return localPath;
      }
    }

    if (_activeDownloads[url] == true) {
      while (_activeDownloads[url] == true) {
        await Future.delayed(const Duration(milliseconds: 100));
        onProgress?.call(_downloadProgress[url] ?? 0);
      }

      onProgress?.call(_downloadProgress[url] ?? 1.0);
      return localPath;
    }

    _activeDownloads[url] = true;
    _downloadProgress[url] = 0;
    notifyListeners();

    try {
      int existingBytes = 0;

      if (await file.exists()) {
        existingBytes = await file.length();
      }

      final req = http.Request('GET', Uri.parse(url));
      if (headers != null) req.headers.addAll(headers);

      if (existingBytes > 0) {
        req.headers['Range'] = 'bytes=$existingBytes-';
      }

      final streamed =
          await _client.send(req).timeout(const Duration(minutes: 10));

      if (streamed.statusCode == 416) {
        _activeDownloads[url] = false;
        _downloadProgress[url] = 1.0;
        notifyListeners();
        onProgress?.call(1.0);
        return localPath;
      }

      if (streamed.statusCode != 200 && streamed.statusCode != 206) {
        throw Exception('HTTP ${streamed.statusCode}');
      }

      int totalSize = streamed.contentLength ?? 0;

      if (streamed.statusCode == 206) {
        totalSize += existingBytes;
      } else {
        existingBytes = 0;
      }

      int received = existingBytes;

      final sink = existingBytes > 0
          ? file.openWrite(mode: FileMode.append)
          : file.openWrite();

      await for (final chunk in streamed.stream) {
        sink.add(chunk);
        received += chunk.length;

        final progress =
            totalSize > 0 ? (received / totalSize).clamp(0.0, 1.0) : 0.0;

        _downloadProgress[url] = progress;
        onProgress?.call(progress);
        notifyListeners();
      }

      await sink.close();

      _downloadProgress[url] = 1.0;
      _activeDownloads[url] = false;
      notifyListeners();
      onProgress?.call(1.0);

      return localPath;
    } catch (e) {
      _activeDownloads[url] = false;
      notifyListeners();
      rethrow;
    }
  }
}

Map<String, String>? authHeaders() {
  final t = ApiClient.instance.token;
  if (t == null || t.isEmpty) return null;
  return {'Authorization': 'Bearer $t'};
}

// ═══════════════════════════════ UTILS ═══════════════════════════
void showSnack(
  BuildContext context,
  String msg, {
  bool error = false,
  int seconds = 3,
}) {
  if (!context.mounted) return;

  final p = _p(context);

  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(SnackBar(
      content: Row(children: [
        Icon(
          error ? Icons.error_outline_rounded : Icons.check_circle_rounded,
          color:
              error ? Colors.white : (p.isDark ? Colors.black : Colors.white),
          size: 20,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            msg,
            style: TextStyle(
              fontSize: 13.5,
              color: error
                  ? Colors.white
                  : (p.isDark ? Colors.black : Colors.white),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ]),
      behavior: SnackBarBehavior.floating,
      backgroundColor: error
          ? p.red
          : (p.isDark ? const Color(0xFFEAF0F6) : const Color(0xFF1A2532)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.all(16),
      duration: Duration(seconds: seconds),
    ));
}

String formatCount(num n) {
  if (n >= 1000000) {
    return '${(n / 1000000).toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')}M';
  }

  if (n >= 1000) {
    return '${(n / 1000).toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')}K';
  }

  return n.toString();
}

String formatDuration(double? seconds) {
  if (seconds == null || seconds <= 0) return '--:--';

  final s = seconds.toInt();
  final m = s ~/ 60;
  final sec = s % 60;

  return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
}

DateTime? _parseServerTime(dynamic v) {
  if (v == null) return null;

  if (v is DateTime) return v.isUtc ? v : v.toUtc();

  if (v is num) {
    if (v < 1e12) {
      return DateTime.fromMillisecondsSinceEpoch(v.toInt() * 1000, isUtc: true);
    }

    if (v < 1e14) {
      return DateTime.fromMillisecondsSinceEpoch(v.toInt(), isUtc: true);
    }

    return DateTime.fromMicrosecondsSinceEpoch(v.toInt(), isUtc: true);
  }

  if (v is String && v.isNotEmpty) {
    final s = v.trim();

    final n = num.tryParse(s);
    if (n != null) return _parseServerTime(n);

    String iso = s;

    if (!iso.endsWith('Z') &&
        !iso.contains('+') &&
        !RegExp(r'\d{2}:\d{2}$').hasMatch(iso)) {
      iso = '${iso}Z';
    }

    final dt = DateTime.tryParse(iso);
    if (dt != null) return dt.isUtc ? dt : dt.toUtc();

    final dt2 = DateTime.tryParse(s);
    if (dt2 != null) return dt2.isUtc ? dt2 : dt2.toUtc();
  }

  return null;
}

String timeAgo(BuildContext context, dynamic v) {
  final t = _parseServerTime(v);
  if (t == null) return '';

  final diff = DateTime.now().toUtc().difference(t).abs();

  if (diff.inSeconds < 5) return 'now';
  if (diff.inSeconds < 60) return '${diff.inSeconds}s';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m';
  if (diff.inHours < 24) return '${diff.inHours}h';
  if (diff.inDays < 7) return '${diff.inDays}d';

  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  if (diff.inDays < 365) return '${months[t.month - 1]} ${t.day}';
  return '${months[t.month - 1]} ${t.day}, ${t.year}';
}

bool isOnline(dynamic lastAt) {
  final t = _parseServerTime(lastAt);
  if (t == null) return false;

  return DateTime.now().toUtc().difference(t).inMinutes <= 2;
}

dynamic jpick(Map j, List<String> keys) {
  for (final k in keys) {
    if (j.containsKey(k) && j[k] != null) return j[k];
  }
  return null;
}

int jint(dynamic v, [int d = 0]) {
  if (v == null) return d;
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? d;
  if (v is bool) return v ? 1 : 0;
  return d;
}

double jdouble(dynamic v, [double d = 0.0]) {
  if (v == null) return d;
  if (v is double) return v;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? d;
  return d;
}

String jstr(dynamic v, [String d = '']) {
  if (v == null) return d;
  return v.toString();
}

bool jbool(dynamic v, [bool d = false]) {
  if (v == null) return d;
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) return v == 'true' || v == '1';
  return d;
}

List<Map<String, dynamic>> extractItems(
  dynamic res, [
  List<String> keys = const [
    'items',
    'posts',
    'results',
    'data',
    'users',
    'notifications',
    'conversations',
    'messages',
    'replies',
    'shorts',
    'media',
    'list',
    'avatars',
    'musics',
    'profile_images',
    'profile_musics',
    'stories',
    'tags'
  ],
]) {
  if (res is List) {
    return res.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  if (res is Map) {
    for (final k in keys) {
      final v = res[k];
      if (v is List) {
        return v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      }
    }

    for (final v in res.values) {
      if (v is List) {
        return v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      }
    }
  }

  return [];
}

String? extractToken(dynamic json) {
  if (json is Map) {
    for (final k in ['token', 'access_token', 'accessToken', 'jwt', 'auth_token']) {
      if (json[k] is String && (json[k] as String).isNotEmpty) return json[k];
    }

    for (final k in ['data', 'user', 'auth', 'session']) {
      if (json[k] is Map) {
        final t = extractToken(json[k]);
        if (t != null) return t;
      }
    }
  }

  return null;
}

String? resolveMedia(dynamic value) {
  if (value == null) return null;

  if (value is Map) {
    for (final k in ['url', 'file_url', 'media_url', 'src', 'link', 'path']) {
      final v = value[k];
      if (v is String && v.isNotEmpty) return resolveMedia(v);
    }

    for (final k in ['id', 'media_id', 'file_id']) {
      final v = value[k];
      if (v != null) return resolveMedia(v.toString());
    }

    return null;
  }

  final s = value.toString().trim();
  if (s.isEmpty) return null;

  if (s.startsWith('http://') || s.startsWith('https://')) return s;

  final base = ApiClient.instance.baseUrl ?? '';
  if (base.isEmpty) return null;

  if (s.startsWith('/')) return '$base$s';
  return '$base/uploads/$s';
}

String _fullUrl(String url) {
  if (url.startsWith('http')) return url;
  return '${ApiClient.instance.baseUrl ?? ''}$url';
}

Color hashColor(String s) {
  const cs = [
    Color(0xFF1D9BF0),
    Color(0xFFF91880),
    Color(0xFF00BA7C),
    Color(0xFF7856FF),
    Color(0xFFFF7A00),
    Color(0xFFFFD400),
  ];

  int h = 0;
  for (final c in s.codeUnits) {
    h = (h * 31 + c) % 997;
  }

  return cs[h % cs.length];
}

class FadeRoute extends PageRouteBuilder {
  final Widget page;

  FadeRoute(this.page)
      : super(
          pageBuilder: (_, __, ___) => page,
          transitionDuration: const Duration(milliseconds: 380),
          reverseTransitionDuration: const Duration(milliseconds: 300),
          transitionsBuilder: (_, a, __, child) => FadeTransition(
            opacity: CurvedAnimation(parent: a, curve: Curves.easeOutCubic),
            child: child,
          ),
        );
}

class SlideUpRoute extends PageRouteBuilder {
  final Widget page;

  SlideUpRoute(this.page)
      : super(
          pageBuilder: (_, __, ___) => page,
          transitionDuration: const Duration(milliseconds: 400),
          reverseTransitionDuration: const Duration(milliseconds: 300),
          transitionsBuilder: (_, a, __, child) => SlideTransition(
            position: Tween(begin: const Offset(0, 1), end: Offset.zero)
                .animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
            child: child,
          ),
        );
}

// ═══════════════════════════════ API CLIENT ══════════════════════
class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  static const String linkSource =
      'https://raw.githubusercontent.com/sksjjsiii/MyFiles/main/link.txt';

  static const Duration _timeout = Duration(seconds: 30);

  String? _baseUrl;
  String? _token;

  final ValueNotifier<int> unauthorized = ValueNotifier(0);

  String? get baseUrl => _baseUrl;
  String? get token => _token;
  bool get hasToken => _token != null && _token!.isNotEmpty;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();

    _token = prefs.getString('pulse_token');
    _baseUrl = prefs.getString('pulse_base_url');
  }

  Future<void> saveToken(String? t) async {
    _token = t;

    final prefs = await SharedPreferences.getInstance();

    if (t == null) {
      await prefs.remove('pulse_token');
    } else {
      await prefs.setString('pulse_token', t);
    }
  }

  Future<String> fetchBaseUrl({bool force = false}) async {
    if (_baseUrl != null && _baseUrl!.isNotEmpty && !force) return _baseUrl!;

    try {
      final res = await http
          .get(Uri.parse(linkSource))
          .timeout(const Duration(seconds: 12));

      if (res.statusCode == 200) {
        var url = res.body.trim();

        if (url.isNotEmpty && url.startsWith('http')) {
          url = url.replaceAll(RegExp(r'/+$'), '');
          _baseUrl = url;

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('pulse_base_url', url);

          return url;
        }
      }
    } catch (e) {
      debugPrint('fetchBaseUrl error: $e');
    }

    if (_baseUrl != null && _baseUrl!.isNotEmpty) return _baseUrl!;
    throw ApiException('Could not reach the server.', statusCode: 0);
  }

  String _extractError(http.Response res) {
    try {
      final j = jsonDecode(res.body);

      if (j is Map) {
        final d = j['detail'] ?? j['message'] ?? j['error'] ?? j['msg'];

        if (d is String) return d;

        if (d is List && d.isNotEmpty) {
          final first = d.first;

          if (first is Map && first['msg'] != null) {
            return first['msg'].toString();
          }

          return first.toString();
        }
      }
    } catch (_) {}

    return 'Request failed (${res.statusCode})';
  }

  Future<dynamic> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
    bool auth = true,
  }) async {
    Object? lastError;

    for (var attempt = 0; attempt < 2; attempt++) {
      final base = await fetchBaseUrl(force: attempt > 0);

      try {
        Uri uri = Uri.parse('$base$path');

        if (query != null && query.isNotEmpty) {
          uri = uri.replace(queryParameters: {...uri.queryParameters, ...query});
        }

        final headers = <String, String>{'Accept': 'application/json'};
        if (auth && _token != null) headers['Authorization'] = 'Bearer $_token';

        String? encoded;

        if (body != null) {
          final clean = <String, dynamic>{};

          body.forEach((k, v) {
            if (v != null) clean[k] = v;
          });

          encoded = jsonEncode(clean);
          headers['Content-Type'] = 'application/json';
        }

        http.Response res;

        switch (method) {
          case 'POST':
            res = await http
                .post(uri, headers: headers, body: encoded)
                .timeout(_timeout);
            break;
          case 'PUT':
            res = await http
                .put(uri, headers: headers, body: encoded)
                .timeout(_timeout);
            break;
          case 'DELETE':
            res = await http.delete(uri, headers: headers).timeout(_timeout);
            break;
          default:
            res = await http.get(uri, headers: headers).timeout(_timeout);
        }

        if (res.statusCode >= 200 && res.statusCode < 300) {
          if (res.body.trim().isEmpty) return <String, dynamic>{};

          try {
            return jsonDecode(res.body);
          } catch (_) {
            return <String, dynamic>{'raw': res.body};
          }
        }

        if (res.statusCode == 401 &&
            !path.startsWith('/api/auth/login') &&
            !path.startsWith('/api/auth/signup')) {
          unauthorized.value++;
          throw ApiException('Session expired. Sign in again.', statusCode: 401);
        }

        throw ApiException(_extractError(res), statusCode: res.statusCode);
      } on ApiException {
        rethrow;
      } on SocketException catch (e) {
        lastError = e;
        continue;
      } on TimeoutException catch (e) {
        lastError = e;
        continue;
      } on HttpException catch (e) {
        lastError = e;
        continue;
      }
    }

    throw ApiException('Network error: $lastError', statusCode: 0);
  }

  Future<dynamic> get(
    String path, {
    Map<String, String>? query,
    bool auth = true,
  }) =>
      request('GET', path, query: query, auth: auth);

  Future<dynamic> post(
    String path, {
    Map<String, dynamic>? body,
    bool auth = true,
  }) =>
      request('POST', path, body: body, auth: auth);

  Future<dynamic> put(
    String path, {
    Map<String, dynamic>? body,
    bool auth = true,
  }) =>
      request('PUT', path, body: body, auth: auth);

  Future<dynamic> delete(String path, {bool auth = true}) =>
      request('DELETE', path, auth: auth);

  Future<dynamic> uploadMedia(
    String filePath, {
    String fieldName = 'file',
    void Function(double progress)? onProgress,
  }) async {
    final file = File(filePath);
    final fileLength = await file.length();

    for (var attempt = 0; attempt < 2; attempt++) {
      final base = await fetchBaseUrl(force: attempt > 0);

      try {
        final req = http.MultipartRequest(
          'POST',
          Uri.parse('$base/api/media/upload'),
        );

        if (_token != null) req.headers['Authorization'] = 'Bearer $_token';

        final stream = http.ByteStream(file.openRead());

        req.files.add(http.MultipartFile(
          fieldName,
          stream,
          fileLength,
          filename: filePath.split('/').last,
        ));

        final trackedRequest = _TrackedMultipartRequest(req, (sentBytes) {
          if (onProgress != null) {
            onProgress(
              fileLength > 0 ? (sentBytes / fileLength).clamp(0.0, 0.99) : 0.0,
            );
          }
        });

        final streamed =
            await trackedRequest.send().timeout(const Duration(minutes: 5));

        final bytes = BytesBuilder();

        await for (final chunk in streamed.stream) {
          bytes.add(chunk);
        }

        if (onProgress != null) onProgress(1.0);

        final bodyBytes = bytes.toBytes();

        final res = http.Response.bytes(
          bodyBytes,
          streamed.statusCode,
          headers: streamed.headers,
          request: streamed.request,
        );

        if (res.statusCode >= 200 && res.statusCode < 300) {
          if (res.body.trim().isEmpty) return <String, dynamic>{};

          try {
            return jsonDecode(res.body);
          } catch (_) {
            return <String, dynamic>{'raw': res.body};
          }
        }

        throw ApiException(_extractError(res), statusCode: res.statusCode);
      } on ApiException {
        rethrow;
      } on SocketException {
        continue;
      } on TimeoutException {
        continue;
      }
    }

    throw ApiException('Upload failed — network error.');
  }
}

class _TrackedMultipartRequest extends http.MultipartRequest {
  final http.MultipartRequest _inner;
  final void Function(int sentBytes) onProgress;

  _TrackedMultipartRequest(this._inner, this.onProgress)
      : super(_inner.method, _inner.url);

  @override
  Map<String, String> get headers => _inner.headers;

  @override
  List<http.MultipartFile> get files => _inner.files;

  @override
  Map<String, String> get fields => _inner.fields;

  @override
  http.ByteStream finalize() {
    final byteStream = _inner.finalize();

    int sent = 0;
    final controller = StreamController<List<int>>();

    byteStream.listen(
      (data) {
        sent += data.length;
        controller.add(data);
        onProgress(sent);
      },
      onError: controller.addError,
      onDone: controller.close,
      cancelOnError: true,
    );

    return http.ByteStream(controller.stream);
  }
}

// ═══════════════════════════════ MODELS ══════════════════════════
class User {
  final int? id;
  final String username;
  final String name;
  final String bio;
  final String email;
  final List<MediaItem> avatarItems;
  final List<MediaItem> musicItems;
  final bool verified;
  final bool isAdmin;
  final bool isFollowing;
  final bool isOnline;
  final int followers;
  final int following;
  final int posts;
  final dynamic lastSeen;
  final bool hasUnseenStory;
  final List<String> followedByFollowings;

  User({
    this.id,
    required this.username,
    this.name = '',
    this.bio = '',
    this.email = '',
    this.avatarItems = const [],
    this.musicItems = const [],
    this.verified = false,
    this.isAdmin = false,
    this.isFollowing = false,
    this.isOnline = false,
    this.followers = 0,
    this.following = 0,
    this.posts = 0,
    this.lastSeen,
    this.hasUnseenStory = false,
    this.followedByFollowings = const [],
  });

  // آخرین آواتار = آواتار پیش‌فرض
  String? get avatarUrl =>
      avatarItems.isNotEmpty ? avatarItems.last.url : null;

  String get displayName => (name.isNotEmpty ? name : username);

  User copyWithUnseenStory(bool value) {
    return User(
      id: id,
      username: username,
      name: name,
      bio: bio,
      email: email,
      avatarItems: avatarItems,
      musicItems: musicItems,
      verified: verified,
      isAdmin: isAdmin,
      isFollowing: isFollowing,
      isOnline: isOnline,
      followers: followers,
      following: following,
      posts: posts,
      lastSeen: lastSeen,
      hasUnseenStory: value,
      followedByFollowings: followedByFollowings,
    );
  }

  factory User.fromJson(Map<String, dynamic> raw) {
    Map<String, dynamic> j = raw;

    for (final k in ['user', 'profile', 'account', 'data', 'author', 'member']) {
      if (j[k] is Map) {
        j = Map<String, dynamic>.from(j[k]);
        break;
      }
    }

    List<MediaItem> avatars = [];

    final avList = jpick(
      j,
      ['profile_images', 'profile_image_ids', 'avatar_ids', 'avatars'],
    );

    if (avList is List) {
      avatars = avList
          .map(MediaItem.fromDynamic)
          .where((m) => m.url.isNotEmpty)
          .toList();
    }

    if (avatars.isEmpty) {
      final single = jpick(
        j,
        ['avatar', 'avatar_url', 'profile_image', 'profile_picture'],
      );

      final u = resolveMedia(single);

      if (u != null && u.isNotEmpty) {
        avatars = [MediaItem(url: u, type: 'image')];
      }
    }

    List<MediaItem> musics = [];

    final muList = jpick(
      j,
      ['profile_music', 'profile_music_ids', 'music_ids', 'musics'],
    );

    if (muList is List) {
      musics = muList
          .map(MediaItem.fromDynamic)
          .where((m) => m.url.isNotEmpty)
          .toList();
    }

    if (musics.isEmpty) {
      final single = jpick(j, ['music', 'music_url']);
      final u = resolveMedia(single);

      if (u != null && u.isNotEmpty) {
        musics = [MediaItem(url: u, type: 'audio')];
      }
    }

    final followedByRaw = jpick(j, ['followed_by_followings']);

    final followedBy = followedByRaw is List
        ? followedByRaw.map((e) => e.toString()).toList()
        : <String>[];

    final idRaw = jpick(j, ['id', 'user_id', '_id']);

    return User(
      id: idRaw is int ? idRaw : int.tryParse(jstr(idRaw)),
      username: jstr(jpick(j, ['username', 'handle'])),
      name: jstr(jpick(j, ['name', 'display_name'])),
      bio: jstr(jpick(j, ['bio', 'about'])),
      email: jstr(jpick(j, ['email'])),
      avatarItems: avatars,
      musicItems: musics,
      verified: jbool(jpick(j, ['is_verified', 'verified'])),
      isAdmin: jbool(jpick(j, ['is_admin', 'admin'])),
      isFollowing: jbool(jpick(j, ['following', 'is_following'])),
      isOnline: jbool(jpick(j, ['online'])),
      followers: jint(jpick(j, ['followers_count', 'followers'])),
      following: jint(jpick(j, ['following_count', 'follows_count'])),
      posts: jint(jpick(j, ['posts_count', 'post_count'])),
      lastSeen: jpick(j, ['last_seen', 'last_seen_at']),
      hasUnseenStory: jbool(jpick(j, ['has_unseen_story'])),
      followedByFollowings: followedBy,
    );
  }
}

class MediaItem {
  final String? id;
  final String url;
  final String? thumbnail;
  final String type;
  final String? originalName;
  final String? mimeType;
  final String? title;
  final String? artist;
  final double? duration;

  MediaItem({
    this.id,
    required this.url,
    this.thumbnail,
    this.type = 'image',
    this.originalName,
    this.mimeType,
    this.title,
    this.artist,
    this.duration,
  });

  factory MediaItem.fromDynamic(dynamic v) {
    String? id, url, thumb, originalName, mimeType, title, artist;
    double? duration;
    String type = 'image';

    if (v is Map) {
      id = jstr(jpick(v, ['id', 'media_id']));
      url = resolveMedia(jpick(v, ['url', 'file_url', 'media_url', 'path']));
      thumb = resolveMedia(jpick(v, ['thumbnail', 'thumb', 'thumb_url']));
      originalName = jstr(jpick(v, ['original_name', 'name', 'filename']));
      mimeType = jstr(jpick(v, ['mime_type', 'content_type']));
      title = jstr(jpick(v, ['title']));
      artist = jstr(jpick(v, ['artist']));
      duration = jdouble(jpick(v, ['duration']));

      final t = jstr(jpick(v, ['media_type', 'type'])).toLowerCase();

      if (t == 'video' || t.contains('video')) {
        type = 'video';
      } else if (t == 'gif' || t.contains('gif')) {
        type = 'gif';
      } else if (t == 'audio' || t.contains('audio')) {
        type = 'audio';
      } else if (t == 'file') {
        type = 'file';
      } else {
        type = 'image';
      }
    } else if (v != null) {
      final s = v.toString();
      url = resolveMedia(s);
      id = s;
    }

    if (url != null && type == 'image') {
      final lower = url.split('?').first.toLowerCase();

      if (['.mp4', '.mov', '.webm'].any(lower.endsWith)) type = 'video';
      if (['.mp3', '.wav', '.ogg', '.m4a'].any(lower.endsWith)) type = 'audio';
      if (lower.endsWith('.gif')) type = 'gif';
    }

    return MediaItem(
      id: id,
      url: url ?? '',
      thumbnail: thumb,
      type: type,
      originalName: originalName,
      mimeType: mimeType,
      title: title,
      artist: artist,
      duration: duration,
    );
  }
}

class Post {
  int? id;
  String text;
  List<MediaItem> media;
  User? author;

  int replyCount;
  int retweetCount;
  int likeCount;
  int shareCount;
  int bookmarkCount;
  int quoteCount;

  bool liked;
  bool retweeted;
  bool bookmarked;

  dynamic createdAt;
  dynamic editedAt;

  int? parentId;
  int? quotedPostId;
  int? repostOfId;

  Post? quoted;
  Post? repostOf;

  List<String> likedByFollowings;
  List<String> repostedByFollowings;

  Post({
    this.id,
    this.text = '',
    this.media = const [],
    this.author,
    this.replyCount = 0,
    this.retweetCount = 0,
    this.likeCount = 0,
    this.shareCount = 0,
    this.bookmarkCount = 0,
    this.quoteCount = 0,
    this.liked = false,
    this.retweeted = false,
    this.bookmarked = false,
    this.createdAt,
    this.editedAt,
    this.parentId,
    this.quotedPostId,
    this.repostOfId,
    this.quoted,
    this.repostOf,
    this.likedByFollowings = const [],
    this.repostedByFollowings = const [],
  });

  factory Post.fromJson(Map<String, dynamic> raw) {
    Map<String, dynamic> j = raw;

    for (final k in ['post', 'data', 'item', 'tweet']) {
      if (j[k] is Map) {
        j = Map<String, dynamic>.from(j[k]);
        break;
      }
    }

    List<MediaItem> media = [];

    final mraw = jpick(j, ['media', 'media_items', 'attachments', 'files']);

    if (mraw is List) {
      media = mraw
          .map(MediaItem.fromDynamic)
          .where((m) => m.url.isNotEmpty)
          .toList();
    }

    User? author;

    final araw = jpick(j, ['user', 'author', 'owner', 'profile']);

    if (araw is Map) {
      author = User.fromJson(Map<String, dynamic>.from(araw));
    }

    Post? quoted;

    final qraw = jpick(j, ['quoted_post', 'quoted', 'quote']);

    if (qraw is Map) {
      quoted = Post.fromJson(Map<String, dynamic>.from(qraw));
    }

    Post? repostOf;

    final rraw = jpick(j, ['repost_of', 'reposted_post']);

    if (rraw is Map) {
      repostOf = Post.fromJson(Map<String, dynamic>.from(rraw));
    }

    final likedByRaw = jpick(j, ['liked_by_followings']);

    final likedBy = likedByRaw is List
        ? likedByRaw.map((e) => e.toString()).toList()
        : <String>[];

    final repostedByRaw = jpick(j, ['reposted_by_followings']);

    final repostedBy = repostedByRaw is List
        ? repostedByRaw.map((e) => e.toString()).toList()
        : <String>[];

    final idRaw = jpick(j, ['id', 'post_id']);

    return Post(
      id: idRaw is int ? idRaw : int.tryParse(jstr(idRaw)),
      text: jstr(jpick(j, ['text', 'content', 'body', 'caption'])),
      media: media,
      author: author,
      replyCount: jint(jpick(j, ['replies_count', 'reply_count'])),
      retweetCount: jint(jpick(j, ['retweets_count', 'retweet_count'])),
      likeCount: jint(jpick(j, ['likes_count', 'like_count'])),
      shareCount: jint(jpick(j, ['shares_count', 'share_count'])),
      bookmarkCount: jint(jpick(j, ['bookmarks_count', 'bookmark_count'])),
      quoteCount: jint(jpick(j, ['quotes_count', 'quote_count'])),
      liked: jbool(jpick(j, ['liked', 'is_liked'])),
      retweeted: jbool(jpick(j, ['retweeted', 'is_retweeted'])),
      bookmarked: jbool(jpick(j, ['bookmarked', 'is_bookmarked'])),
      createdAt: jpick(j, ['created_at', 'createdAt']),
      editedAt: jpick(j, ['edited_at', 'editedAt']),
      parentId: jint(jpick(j, ['parent_id'])),
      quotedPostId: jint(jpick(j, ['quoted_post_id'])),
      repostOfId: jint(jpick(j, ['repost_of_id'])),
      quoted: quoted,
      repostOf: repostOf,
      likedByFollowings: likedBy,
      repostedByFollowings: repostedBy,
    );
  }
}

class Conversation {
  final int? id;
  final String? name;
  final bool isGroup;
  final List<User> members;
  final DM? lastMessage;
  final int unread;

  Conversation({
    this.id,
    this.name,
    this.isGroup = false,
    this.members = const [],
    this.lastMessage,
    this.unread = 0,
  });

  factory Conversation.fromJson(Map<String, dynamic> raw) {
    Map<String, dynamic> j = raw;

    for (final k in ['conversation', 'data']) {
      if (j[k] is Map) {
        j = Map<String, dynamic>.from(j[k]);
        break;
      }
    }

    List<User> members = [];

    final mraw = jpick(j, ['members', 'participants', 'users']);

    if (mraw is List) {
      members = mraw
          .whereType<Map>()
          .map((e) => User.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }

    DM? lastMessage;

    final lm = jpick(j, ['last_message', 'latest_message']);

    if (lm is Map) {
      lastMessage = DM.fromJson(Map<String, dynamic>.from(lm));
    }

    final idRaw = jpick(j, ['id', 'conversation_id']);

    return Conversation(
      id: idRaw is int ? idRaw : int.tryParse(jstr(idRaw)),
      name: jstr(jpick(j, ['name', 'title'])).isEmpty
          ? null
          : jstr(jpick(j, ['name', 'title'])),
      isGroup: jbool(jpick(j, ['is_group', 'group'])),
      members: members,
      lastMessage: lastMessage,
      unread: jint(jpick(j, ['unread_count', 'unread'])),
    );
  }
}

class DM {
  final int? id;
  final String text;
  final int? senderId;
  final User? sender;
  final List<MediaItem> media;
  final int? replyToId;
  final DM? replyParent;
  final dynamic createdAt;
  final dynamic editedAt;
  final bool deleted;

  DM({
    this.id,
    this.text = '',
    this.senderId,
    this.sender,
    this.media = const [],
    this.replyToId,
    this.replyParent,
    this.createdAt,
    this.editedAt,
    this.deleted = false,
  });

  factory DM.fromJson(Map<String, dynamic> raw) {
    Map<String, dynamic> j = raw;

    for (final k in ['message', 'data']) {
      if (j[k] is Map) {
        j = Map<String, dynamic>.from(j[k]);
        break;
      }
    }

    User? sender;

    final sraw = jpick(j, ['sender', 'user', 'author']);

    if (sraw is Map) {
      sender = User.fromJson(Map<String, dynamic>.from(sraw));
    }

    List<MediaItem> media = [];

    final mraw = jpick(j, ['media', 'attachments', 'media_ids']);

    if (mraw is List) {
      media = mraw
          .map(MediaItem.fromDynamic)
          .where((m) => m.url.isNotEmpty)
          .toList();
    }

    DM? replyParent;

    final rp = jpick(j, ['reply_to', 'reply_parent', 'reply_to_message']);

    if (rp is Map) {
      replyParent = DM.fromJson(Map<String, dynamic>.from(rp));
    }

    final idRaw = jpick(j, ['id', 'message_id']);

    return DM(
      id: idRaw is int ? idRaw : int.tryParse(jstr(idRaw)),
      text: jstr(jpick(j, ['text', 'content', 'body'])),
      senderId: jint(jpick(j, ['sender_id', 'user_id'])),
      sender: sender,
      media: media,
      replyToId: jint(jpick(j, ['reply_to_id', 'reply_to'])),
      replyParent: replyParent,
      createdAt: jpick(j, ['created_at', 'createdAt']),
      editedAt: jpick(j, ['edited_at', 'editedAt']),
      deleted: jbool(jpick(j, ['deleted', 'is_deleted'])),
    );
  }
}

class Noti {
  final int? id;
  final String type;
  final String? text;
  final User? actor;
  final int? postId;
  final int? messageId;
  bool read;
  final dynamic createdAt;

  Noti({
    this.id,
    this.type = '',
    this.text,
    this.actor,
    this.postId,
    this.messageId,
    this.read = false,
    this.createdAt,
  });

  factory Noti.fromJson(Map<String, dynamic> raw) {
    Map<String, dynamic> j = raw;

    for (final k in ['notification', 'data']) {
      if (j[k] is Map) {
        j = Map<String, dynamic>.from(j[k]);
        break;
      }
    }

    User? actor;

    final araw = jpick(j, ['actor', 'user', 'from_user']);

    if (araw is Map) {
      actor = User.fromJson(Map<String, dynamic>.from(araw));
    }

    final idRaw = jpick(j, ['id', 'notification_id']);

    return Noti(
      id: idRaw is int ? idRaw : int.tryParse(jstr(idRaw)),
      type: jstr(jpick(j, ['type', 'kind', 'action'])).toLowerCase(),
      text: jstr(jpick(j, ['text', 'message', 'content'])).isEmpty
          ? null
          : jstr(jpick(j, ['text', 'message', 'content'])),
      actor: actor,
      postId: jint(jpick(j, ['post_id', 'target_id'])),
      messageId: jint(jpick(j, ['message_id'])),
      read: jbool(jpick(j, ['read', 'is_read', 'seen'])),
      createdAt: jpick(j, ['created_at', 'createdAt']),
    );
  }
}

class Story {
  final int id;
  final int userId;
  final MediaItem? media;
  final String text;
  final dynamic createdAt;
  final dynamic expiresAt;
  final bool viewedByMe;
  final int viewersCount;
  final User? user;

  Story({
    required this.id,
    required this.userId,
    this.media,
    this.text = '',
    this.createdAt,
    this.expiresAt,
    this.viewedByMe = false,
    this.viewersCount = 0,
    this.user,
  });

  factory Story.fromJson(Map<String, dynamic> raw) {
    Map<String, dynamic> j = raw;

    for (final k in ['story', 'data']) {
      if (j[k] is Map) {
        j = Map<String, dynamic>.from(j[k]);
        break;
      }
    }

    MediaItem? media;

    final mraw = jpick(j, ['media']);

    if (mraw is Map) media = MediaItem.fromDynamic(mraw);

    User? user;

    final uraw = jpick(j, ['user']);

    if (uraw is Map) user = User.fromJson(Map<String, dynamic>.from(uraw));

    return Story(
      id: jint(jpick(j, ['id', 'story_id'])),
      userId: jint(jpick(j, ['user_id'])),
      media: media,
      text: jstr(jpick(j, ['text'])),
      createdAt: jpick(j, ['created_at']),
      expiresAt: jpick(j, ['expires_at']),
      viewedByMe: jbool(jpick(j, ['viewed_by_me'])),
      viewersCount: jint(jpick(j, ['viewers_count'])),
      user: user,
    );
  }
}

// ═══════════════════════════════ APP STATE ═══════════════════════
class AppState extends ChangeNotifier {
  User? me;

  final ValueNotifier<int> feedTick = ValueNotifier(0);
  final ValueNotifier<int> currentTab = ValueNotifier(0);

  Future<void> fetchMe() async {
    try {
      final res = await ApiClient.instance.get('/api/auth/me');

      if (res is Map) {
        me = User.fromJson(Map<String, dynamic>.from(res));
        notifyListeners();
      }
    } catch (e) {
      debugPrint('fetchMe error: $e');
    }
  }

  Future<void> logout() async {
    await ApiClient.instance.saveToken(null);
    await AudioController.instance.stop();

    me = null;
    notifyListeners();
  }

  void pokeFeed() => feedTick.value++;

  void setTab(int t) {
    currentTab.value = t;
    notifyListeners();
  }
}

Future<void> openUserOrStory(BuildContext context, User? user) async {
  if (user == null) return;

  if (user.id != null && user.hasUnseenStory) {
    await Navigator.push(
      context,
      FadeRoute(StoryViewerScreen(userId: user.id!, user: user)),
    );
  } else {
    Navigator.push(
      context,
      FadeRoute(ProfileScreen(username: user.username)),
    );
  }
}

// ═══════════════════════════════ SPLASH ══════════════════════════
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _pulse;
  late final AnimationController _spin;

  String _status = 'Starting…';
  bool _failed = false;

  @override
  void initState() {
    super.initState();

    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );

    _spin = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _pulse.repeat(reverse: true);
    _spin.repeat();

    _boot();
  }

  Future<void> _boot() async {
    setState(() {
      _failed = false;
      _status = 'Connecting to server…';
    });

    try {
      await ApiClient.instance.fetchBaseUrl(force: true);
      if (!mounted) return;

      if (ApiClient.instance.hasToken) {
        setState(() => _status = 'Signing you in…');
        await context.read<AppState>().fetchMe();
      }

      if (!mounted) return;

      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;

      final me = context.read<AppState>().me;

      Navigator.of(context).pushReplacement(
        FadeRoute(me != null ? const MainShell() : const AuthScreen()),
      );
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _failed = true;
        _status = 'Could not reach the server';
      });
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = _p(context);

    return Scaffold(
      backgroundColor: p.bg,
      body: Stack(fit: StackFit.expand, children: [
        Positioned(top: -120, left: -100, child: _blob(p.accent, 320)),
        Positioned(bottom: -140, right: -100, child: _blob(p.purple, 340)),
        Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ScaleTransition(
              scale: Tween(begin: .92, end: 1.06).animate(
                CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
              ),
              child: Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  gradient: p.brand,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: p.accent.withOpacity(.45),
                      blurRadius: 46,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: const Icon(Icons.bolt_rounded, size: 56, color: Colors.white),
              ),
            ),
            const SizedBox(height: 26),
            ShaderMask(
              shaderCallback: (b) => p.brand.createShader(Offset.zero & b.size),
              child: const Text(
                'NokhodX',
                style: TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Feel every moment',
              style: TextStyle(color: p.sub, fontSize: 14),
            ),
            const SizedBox(height: 44),
            if (_failed)
              Column(children: [
                Text(_status, style: TextStyle(color: p.red, fontSize: 13)),
                const SizedBox(height: 16),
                GradientButton(
                  text: 'Retry',
                  icon: Icons.refresh_rounded,
                  width: 180,
                  onPressed: _boot,
                ),
              ])
            else
              Column(children: [
                SizedBox(
                  width: 26,
                  height: 26,
                  child: AnimatedBuilder(
                    animation: _spin,
                    builder: (_, __) => Transform.rotate(
                      angle: _spin.value * 6.283,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.6,
                        value: .8,
                        color: p.text.withOpacity(.9),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(_status, style: TextStyle(color: p.sub, fontSize: 13)),
              ]),
          ]),
        ),
      ]),
    );
  }

  Widget _blob(Color c, double size) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [c.withOpacity(.25), Colors.transparent]),
        ),
      );
}

// ═══════════════════════════════ AUTH ════════════════════════════
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with TickerProviderStateMixin {
  bool _signup = false;
  bool _busy = false;
  bool _obscure = true;

  final _identifier = TextEditingController();
  final _email = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();

  final _api = ApiClient.instance;

  @override
  void dispose() {
    _identifier.dispose();
    _email.dispose();
    _username.dispose();
    _password.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;

    FocusScope.of(context).unfocus();
    setState(() => _busy = true);

    try {
      if (_signup) {
        if (_email.text.trim().isEmpty ||
            _username.text.trim().isEmpty ||
            _password.text.isEmpty) {
          throw ApiException('Fill in email, username and password.');
        }

        await _api.post('/api/auth/signup', auth: false, body: {
          'email': _email.text.trim(),
          'username': _username.text.trim(),
          'password': _password.text,
          'name': _name.text.trim(),
        });

        try {
          final res = await _api.post('/api/auth/login', auth: false, body: {
            'identifier': _username.text.trim(),
            'password': _password.text,
          });

          final t = extractToken(res);
          if (t != null) await _api.saveToken(t);
        } catch (_) {}
      }

      if (!_api.hasToken) {
        final res = await _api.post('/api/auth/login', auth: false, body: {
          'identifier':
              _signup ? _username.text.trim() : _identifier.text.trim(),
          'password': _password.text,
        });

        final t = extractToken(res);
        if (t == null) throw ApiException('Login failed — no token received.');

        await _api.saveToken(t);
      }

      final appState = context.read<AppState>();
      await appState.fetchMe();

      appState.me ??= User(
        username: _signup ? _username.text.trim() : _identifier.text.trim(),
        name: _name.text.trim(),
      );

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        FadeRoute(const MainShell()),
        (_) => false,
      );
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } catch (e) {
      if (mounted) showSnack(context, 'Something went wrong.', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _field({
    required TextEditingController c,
    required String hint,
    required IconData icon,
    bool obscure = false,
    TextInputType type = TextInputType.text,
    Widget? suffix,
  }) {
    final p = _p(context);

    return TextField(
      controller: c,
      obscureText: obscure,
      keyboardType: type,
      style: TextStyle(fontSize: 15, color: p.text),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: p.sub, fontSize: 14),
        prefixIcon: Icon(icon, color: p.sub, size: 21),
        suffixIcon: suffix,
        filled: true,
        fillColor: p.card,
        contentPadding: const EdgeInsets.symmetric(vertical: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: p.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: p.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: p.accent, width: 1.4),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _applyBars(context);

    final p = _p(context);

    return Scaffold(
      backgroundColor: p.bg,
      body: Stack(fit: StackFit.expand, children: [
        Positioned(
          top: -100,
          right: -80,
          child: Container(
            width: 280,
            height: 280,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [p.purple.withOpacity(.28), Colors.transparent],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: -120,
          left: -90,
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [p.accent.withOpacity(.22), Colors.transparent],
              ),
            ),
          ),
        ),
        SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: Column(children: [
                  Container(
                    width: 74,
                    height: 74,
                    decoration: BoxDecoration(
                      gradient: p.brand,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(color: p.accent.withOpacity(.4), blurRadius: 34)
                      ],
                    ),
                    child: const Icon(Icons.bolt_rounded, size: 42, color: Colors.white),
                  ),
                  const SizedBox(height: 18),
                  ShaderMask(
                    shaderCallback: (b) => p.brand.createShader(Offset.zero & b.size),
                    child: const Text(
                      'NokhodX',
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _signup ? 'Create your account' : 'Welcome back 👋',
                    style: TextStyle(color: p.sub, fontSize: 14),
                  ),
                  const SizedBox(height: 28),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 340),
                    transitionBuilder: (child, anim) => FadeTransition(
                      opacity: anim,
                      child: SlideTransition(
                        position: Tween(
                          begin: const Offset(0, .06),
                          end: Offset.zero,
                        ).animate(anim),
                        child: child,
                      ),
                    ),
                    child: Container(
                      key: ValueKey(_signup),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: p.surface,
                        borderRadius: BorderRadius.circular(26),
                        border: Border.all(color: p.border),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(.2),
                            blurRadius: 30,
                            offset: const Offset(0, 14),
                          )
                        ],
                      ),
                      child: Column(children: [
                        if (_signup) ...[
                          _field(
                            c: _name,
                            hint: 'Display name',
                            icon: Icons.badge_outlined,
                          ),
                          const SizedBox(height: 12),
                          _field(
                            c: _email,
                            hint: 'Email',
                            icon: Icons.email_outlined,
                            type: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 12),
                          _field(
                            c: _username,
                            hint: 'Username',
                            icon: Icons.alternate_email_rounded,
                          ),
                          const SizedBox(height: 12),
                        ] else ...[
                          _field(
                            c: _identifier,
                            hint: 'Username or email',
                            icon: Icons.person_outline_rounded,
                          ),
                          const SizedBox(height: 12),
                        ],
                        _field(
                          c: _password,
                          hint: 'Password',
                          icon: Icons.lock_outline_rounded,
                          obscure: _obscure,
                          suffix: IconButton(
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: p.sub,
                              size: 20,
                            ),
                            onPressed: () => setState(() => _obscure = !_obscure),
                          ),
                        ),
                        const SizedBox(height: 20),
                        GradientButton(
                          text: _signup ? 'Create account' : 'Sign in',
                          loading: _busy,
                          onPressed: _busy ? null : _submit,
                        ),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(
                      _signup
                          ? 'Already have an account?'
                          : "Don't have an account?",
                      style: TextStyle(color: p.sub, fontSize: 13.5),
                    ),
                    TextButton(
                      onPressed: () => setState(() {
                        _signup = !_signup;
                        _obscure = true;
                      }),
                      child: Text(
                        _signup ? 'Sign in' : 'Sign up',
                        style: TextStyle(
                          color: p.accent,
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                  ]),
                ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════ MAIN SHELL ══════════════════════
class MainShell extends StatefulWidget {
  final int initialTab;

  const MainShell({super.key, this.initialTab = 0});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int _tab = widget.initialTab;
  bool _handlingUnauth = false;

  @override
  void initState() {
    super.initState();

    ApiClient.instance.unauthorized.addListener(_onUnauth);
    context.read<AppState>().setTab(_tab);
  }

  void _onUnauth() {
    if (_handlingUnauth || !mounted) return;

    _handlingUnauth = true;

    context.read<AppState>().logout();
    showSnack(context, 'Session expired — sign in again.', error: true);

    Navigator.of(context).pushAndRemoveUntil(
      FadeRoute(const AuthScreen()),
      (_) => false,
    );
  }

  @override
  void dispose() {
    ApiClient.instance.unauthorized.removeListener(_onUnauth);
    super.dispose();
  }

  void _go(int i) {
    setState(() => _tab = i);
    context.read<AppState>().setTab(i);
    _applyBars(context);
  }

  @override
  Widget build(BuildContext context) {
    final p = _p(context);
    final audio = context.watch<AudioController>();
    final isShorts = _tab == 2;

    return Scaffold(
      backgroundColor: isShorts ? Colors.black : p.bg,
      extendBody: true,
      body: SafeArea(
        top: !isShorts,
        bottom: false,
        child: Column(children: [
          if (audio.hasTrack && !isShorts) const _MiniPlayer(),
          Expanded(
            child: IndexedStack(index: _tab, children: const [
              HomeScreen(),
              ExploreScreen(),
              ShortsScreen(),
              NotificationsScreen(),
              MessagesScreen(),
            ]),
          ),
        ]),
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).padding.bottom + 6,
          top: 8,
        ),
        decoration: BoxDecoration(
          color: isShorts ? Colors.black : p.surface,
          border: Border(
            top: BorderSide(color: isShorts ? Colors.black12 : p.border),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.15),
              blurRadius: 24,
              offset: const Offset(0, -6),
            )
          ],
        ),
        child: Row(children: [
          _navItem(0, Icons.home_rounded, Icons.home_outlined, 'Home'),
          _navItem(1, Icons.explore_rounded, Icons.explore_outlined, 'Explore'),
          _shortsItem(),
          _navItem(
            3,
            Icons.notifications_rounded,
            Icons.notifications_none_rounded,
            'Notifs',
          ),
          _navItem(
            4,
            Icons.chat_bubble_rounded,
            Icons.chat_bubble_outline_rounded,
            'Messages',
          ),
        ]),
      ),
    );
  }

  Widget _navItem(int i, IconData filled, IconData outlined, String label) {
    final p = _p(context);
    final selected = _tab == i;
    final isShorts = _tab == 2;

    final iconColor = isShorts
        ? (selected ? p.accent : Colors.white54)
        : (selected ? p.accent : p.sub);

    final textColor = isShorts
        ? (selected ? p.accent : Colors.white54)
        : (selected ? p.accent : p.sub);

    return Expanded(
      child: InkWell(
        onTap: () => _go(i),
        borderRadius: BorderRadius.circular(16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          AnimatedScale(
            scale: selected ? 1.12 : 1,
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutBack,
            child: Icon(selected ? filled : outlined, color: iconColor, size: 26),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ]),
      ),
    );
  }

  Widget _shortsItem() {
    final p = _p(context);
    final selected = _tab == 2;

    return Expanded(
      child: GestureDetector(
        onTap: () => _go(2),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          AnimatedScale(
            scale: selected ? 1.12 : 1,
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutBack,
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                gradient: p.reel,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: p.pink.withOpacity(selected ? .55 : .3),
                    blurRadius: selected ? 22 : 12,
                  )
                ],
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 30,
              ),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'Shorts',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: selected ? p.accent : (_tab == 2 ? Colors.white54 : p.sub),
            ),
          ),
        ]),
      ),
    );
  }
}

class _MiniPlayer extends StatelessWidget {
  const _MiniPlayer();

  @override
  Widget build(BuildContext context) {
    final p = _p(context);
    final audio = context.watch<AudioController>();

    if (!audio.hasTrack) return const SizedBox.shrink();

    final progress = audio.currentDuration != null && audio.currentDuration! > 0
        ? (audio.position / audio.currentDuration!).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: p.card,
        border: Border(bottom: BorderSide(color: p.border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Column(children: [
        LinearProgressIndicator(
          value: progress,
          color: p.accent,
          backgroundColor: p.card2,
          minHeight: 2,
        ),
        const SizedBox(height: 6),
        Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: p.brand,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.music_note_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  audio.currentTitle ?? 'Now playing',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                ),
                Text(
                  audio.currentArtist ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 10, color: p.sub),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              audio.playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: p.text,
              size: 24,
            ),
            onPressed: () {
              if (audio.playing) {
                audio.pause();
              } else {
                audio.resume();
              }
            },
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            padding: EdgeInsets.zero,
          ),
          IconButton(
            icon: Icon(Icons.close_rounded, color: p.sub, size: 18),
            onPressed: () => audio.stop(),
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            padding: EdgeInsets.zero,
          ),
        ]),
      ]),
    );
  }
}

// ═══════════════════════════════ HOME ════════════════════════════
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _api = ApiClient.instance;
  final _scroll = ScrollController();

  List<Post> _posts = [];
  List<User> _storyUsers = [];

  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;

  @override
  void initState() {
    super.initState();

    _scroll.addListener(_onScroll);
    context.read<AppState>().feedTick.addListener(_onTick);

    _load(reset: true);
    _loadStories();
  }

  void _onTick() {
    if (!_loading) _load(reset: true, silent: true);
  }

  void _onScroll() {
    if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 500 &&
        !_loadingMore &&
        _hasMore &&
        !_loading) {
      _loadMore();
    }
  }

  Future<void> _loadStories() async {
    try {
      final res = await _api.get('/api/stories/feed');
      if (!mounted) return;

      final stories = extractItems(res).map(Story.fromJson).toList();
      final seenUsers = <int, User>{};

      for (final s in stories) {
        if (s.user != null && !seenUsers.containsKey(s.userId)) {
          seenUsers[s.userId] = s.user!;
        }
      }

      setState(() {
        _storyUsers = seenUsers.values.toList();
      });
    } catch (_) {}
  }

  Future<void> _load({required bool reset, bool silent = false}) async {
    if (reset && !silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final res = await _api.get(
        '/api/feed',
        query: {'limit': '20', 'offset': '0'},
      );

      final items = extractItems(res).map(Post.fromJson).toList();
      if (!mounted) return;

      setState(() {
        _posts = items;
        _loading = false;
        _hasMore = items.length >= 20;
        _error = null;
      });
    } on ApiException catch (e) {
      if (e.statusCode == 401) return;

      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = 'Could not load feed.';
      });
    }
  }

  Future<void> _loadMore() async {
    setState(() => _loadingMore = true);

    try {
      final res = await _api.get(
        '/api/feed',
        query: {'limit': '20', 'offset': '${_posts.length}'},
      );

      final items = extractItems(res).map(Post.fromJson).toList();
      if (!mounted) return;

      setState(() {
        _posts.addAll(items);
        _hasMore = items.length >= 20;
        _loadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _applyBars(context);

    final p = _p(context);
    final me = context.watch<AppState>().me;

    return Stack(children: [
      Column(children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: p.border.withOpacity(.5))),
          ),
          child: Row(children: [
            GestureDetector(
              onTap: me == null
                  ? null
                  : () => Navigator.push(
                        context,
                        FadeRoute(ProfileScreen(username: me.username)),
                      ),
              child: Avatar(
                url: me?.avatarUrl,
                size: 36,
                ring: me?.hasUnseenStory ?? false,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Center(
                child: Text(
                  'NokhodX',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .8,
                  ),
                ),
              ),
            ),
            IconButton(
              icon: Icon(Icons.bookmark_outline_rounded, color: p.sub),
              onPressed: () => Navigator.push(
                context,
                FadeRoute(const BookmarksScreen()),
              ),
            ),
            IconButton(
              icon: Icon(Icons.tune_rounded, color: p.sub),
              onPressed: () => openSettings(context),
            ),
          ]),
        ),
        Expanded(
          child: _loading
              ? ListView(
                  padding: EdgeInsets.zero,
                  children: const [ShimmerPost(), ShimmerPost(), ShimmerPost()],
                )
              : _error != null
                  ? ErrorState(message: _error!, onRetry: () => _load(reset: true))
                  : _posts.isEmpty
                      ? const EmptyState(
                          icon: Icons.notes_rounded,
                          title: 'No posts yet',
                          subtitle: 'Be the first to share something!',
                        )
                      : RefreshIndicator(
                          onRefresh: () => _load(reset: true, silent: true),
                          color: p.accent,
                          backgroundColor: p.card2,
                          child: CustomScrollView(
                            controller: _scroll,
                            slivers: [
                              if (me != null)
                                SliverToBoxAdapter(
                                  child: SizedBox(
                                    height: 94,
                                    child: ListView(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      scrollDirection: Axis.horizontal,
                                      children: [
                                        _StoryAddButton(me: me, onDone: _loadStories),
                                        const SizedBox(width: 8),
                                        ..._storyUsers.map(
                                          (u) => _StoryRing(
                                            user: u,
                                            onChanged: _loadStories,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              SliverPadding(
                                padding: const EdgeInsets.only(bottom: 160),
                                sliver: SliverList(
                                  delegate: SliverChildBuilderDelegate(
                                    (context, i) {
                                      if (i == _posts.length) {
                                        return _loadingMore
                                            ? const Padding(
                                                padding: EdgeInsets.all(20),
                                                child: Center(
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2.4,
                                                  ),
                                                ),
                                              )
                                            : const SizedBox(height: 1);
                                      }

                                      return Column(children: [
                                        SlideFadeIn(
                                          delay: Duration(
                                            milliseconds: (i % 8) * 45,
                                          ),
                                          child: PostCard(
                                            post: _posts[i],
                                            onChanged: () => setState(() {}),
                                            onDeleted: () =>
                                                setState(() => _posts.removeAt(i)),
                                          ),
                                        ),
                                        Divider(
                                          height: 1,
                                          thickness: 1,
                                          color: p.border.withOpacity(.4),
                                        ),
                                      ]);
                                    },
                                    childCount: _posts.length + 1,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
        ),
      ]),
      Positioned(
        right: 20,
        bottom: MediaQuery.of(context).padding.bottom + 80,
        child: GestureDetector(
          onTap: () => Navigator.push(
            context,
            SlideUpRoute(const ComposeScreen()),
          ).then((v) {
            if (v == true) {
              _load(reset: true, silent: true);
            }
          }),
          child: Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              gradient: p.brand,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: p.accent.withOpacity(.5), blurRadius: 22)
              ],
            ),
            child: const Icon(Icons.add_rounded, color: Colors.white, size: 30),
          ),
        ),
      ),
    ]);
  }
}

// ═══════════════════════════════ STORIES ═══════════════════════════
class _StoryRing extends StatelessWidget {
  final User user;
  final VoidCallback? onChanged;

  const _StoryRing({required this.user, this.onChanged});

  @override
  Widget build(BuildContext context) {
    final p = _p(context);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          FadeRoute(StoryViewerScreen(userId: user.id!, user: user)),
        ).then((_) => onChanged?.call());
      },
      child: Container(
        width: 74,
        margin: const EdgeInsets.only(right: 4),
        child: Column(children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: user.hasUnseenStory ? p.reel : null,
              border: user.hasUnseenStory
                  ? null
                  : Border.all(color: p.border, width: 2),
            ),
            child: Avatar(url: user.avatarUrl, size: 58, ring: false),
          ),
          const SizedBox(height: 4),
          Text(
            user.username,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ]),
      ),
    );
  }
}

class _StoryAddButton extends StatelessWidget {
  final User me;
  final VoidCallback onDone;

  const _StoryAddButton({required this.me, required this.onDone});

  @override
  Widget build(BuildContext context) {
    final p = _p(context);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          SlideUpRoute(const CreateStoryScreen()),
        ).then((v) {
          if (v == true) onDone();
        });
      },
      child: Container(
        width: 74,
        margin: const EdgeInsets.only(right: 4),
        child: Column(children: [
          Stack(children: [
            Avatar(url: me.avatarUrl, size: 62, ring: false),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  gradient: p.brand,
                  shape: BoxShape.circle,
                  border: Border.all(color: p.bg, width: 2),
                ),
                child: const Icon(Icons.add_rounded, color: Colors.white, size: 16),
              ),
            ),
          ]),
          const SizedBox(height: 4),
          const Text(
            'Your story',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ]),
      ),
    );
  }
}

class CreateStoryScreen extends StatefulWidget {
  const CreateStoryScreen({super.key});

  @override
  State<CreateStoryScreen> createState() => _CreateStoryScreenState();
}

class _CreateStoryScreenState extends State<CreateStoryScreen> {
  final _text = TextEditingController();

  String? _mediaId;
  String? _mediaPreview;

  double _uploadProgress = 0;
  bool _uploading = false;
  bool _posting = false;

  Future<void> _pickMedia() async {
    final f = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );

    if (f == null) return;

    setState(() {
      _mediaPreview = f.path;
      _uploading = true;
      _uploadProgress = 0;
    });

    try {
      final res = await ApiClient.instance.uploadMedia(
        f.path,
        onProgress: (v) {
          if (mounted) setState(() => _uploadProgress = v);
        },
      );

      if (res is Map) {
        setState(() {
          _mediaId = jstr(jpick(res, ['id', 'media_id']));
          _uploading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _uploading = false);
        showSnack(context, 'Upload failed', error: true);
      }
    }
  }

  Future<void> _post() async {
    if (_posting || _uploading) return;

    if (_text.text.trim().isEmpty && _mediaId == null) {
      showSnack(context, 'Write something or add media', error: true);
      return;
    }

    setState(() => _posting = true);

    try {
      await ApiClient.instance.post('/api/stories', body: {
        'text': _text.text.trim(),
        if (_mediaId != null) 'media_id': _mediaId,
      });

      if (mounted) {
        showSnack(context, 'Story posted!');
        Navigator.pop(context, true);
      }
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = _p(context);

    return Scaffold(
      backgroundColor: p.bg,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: p.sub),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Add story',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GradientButton(
              text: 'Post story',
              width: 110,
              height: 40,
              loading: _posting || _uploading,
              onPressed: (_posting || _uploading) ? null : _post,
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          GestureDetector(
            onTap: _uploading ? null : _pickMedia,
            child: Container(
              width: double.infinity,
              height: 280,
              decoration: BoxDecoration(
                color: p.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: p.border),
              ),
              child: _mediaPreview != null
                  ? Stack(fit: StackFit.expand, children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.file(File(_mediaPreview!), fit: BoxFit.cover),
                      ),
                      if (_uploading)
                        Positioned.fill(
                          child: Container(
                            color: Colors.black.withOpacity(0.5),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 50,
                                    height: 50,
                                    child: CircularProgressIndicator(
                                      value: _uploadProgress,
                                      color: p.accent,
                                      strokeWidth: 3,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '${(_uploadProgress * 100).toInt()}%',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ])
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_photo_alternate_outlined, color: p.sub, size: 50),
                        const SizedBox(height: 8),
                        Text('Add story', style: TextStyle(color: p.sub, fontSize: 13)),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _text,
            maxLines: 4,
            minLines: 2,
            style: TextStyle(fontSize: 16, color: p.text),
            decoration: InputDecoration(
              hintText: 'Share your moment…',
              hintStyle: TextStyle(color: p.sub),
              filled: true,
              fillColor: p.card,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
        ]),
      ),
    );
  }
}

class StoryViewerScreen extends StatefulWidget {
  final int userId;
  final User user;

  const StoryViewerScreen({
    super.key,
    required this.userId,
    required this.user,
  });

  @override
  State<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends State<StoryViewerScreen> {
  List<Story> _stories = [];
  int _current = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await ApiClient.instance.get('/api/stories/${widget.userId}');
      if (!mounted) return;

      final items = extractItems(res).map(Story.fromJson).toList();

      setState(() {
        _stories = items;
        _loading = false;
      });

      for (final s in items) {
        if (!s.viewedByMe) {
          ApiClient.instance
              .post('/api/stories/${s.id}/view')
              .catchError((_) {});
        }
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    if (_stories.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Center(
            child: Text(
              'No stories',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
          ),
        ),
      );
    }

    final story = _stories[_current];

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapUp: (details) {
          final w = MediaQuery.of(context).size.width;

          if (details.globalPosition.dx < w / 3) {
            if (_current > 0) setState(() => _current--);
          } else {
            if (_current < _stories.length - 1) {
              setState(() => _current++);
            } else {
              Navigator.pop(context);
            }
          }
        },
        child: Stack(fit: StackFit.expand, children: [
          if (story.media != null && story.media!.type == 'image')
            CachedNetworkImage(
              imageUrl: story.media!.url,
              fit: BoxFit.contain,
            )
          else if (story.media != null &&
              (story.media!.type == 'video' || story.media!.type == 'gif'))
            _StoryVideo(url: story.media!.url)
          else
            Container(
              decoration: BoxDecoration(gradient: Pal(isDark: true).brand),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Text(
                    story.text,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16,
            right: 16,
            child: Column(children: [
              Row(children: [
                for (int i = 0; i < _stories.length; i++)
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      height: 3,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor:
                            i < _current ? 1.0 : (i == _current ? 1.0 : 0.0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                  ),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Avatar(url: widget.user.avatarUrl, size: 36),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '@${widget.user.username}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white, size: 26),
                  onPressed: () => Navigator.pop(context),
                ),
              ]),
            ]),
          ),
          if (story.text.isNotEmpty && story.media != null)
            Positioned(
              left: 20,
              right: 20,
              bottom: 40,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(.5),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  story.text,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}

class _StoryVideo extends StatefulWidget {
  final String url;

  const _StoryVideo({required this.url});

  @override
  State<_StoryVideo> createState() => _StoryVideoState();
}

class _StoryVideoState extends State<_StoryVideo> {
  VideoPlayerController? _c;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    AudioController.instance.muteTemporarily();

    final c = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _c = c;

    try {
      await c.initialize();
      c.setLooping(true);
      await c.play();

      if (mounted) setState(() {});
    } catch (_) {}
  }

  @override
  void dispose() {
    AudioController.instance.unmute();
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_c == null || !_c!.value.isInitialized) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    return Center(
      child: AspectRatio(
        aspectRatio: _c!.value.aspectRatio,
        child: VideoPlayer(_c!),
      ),
    );
  }
}

// ═══════════════════════════════ POST CARD ═══════════════════════
class ActionButton extends StatefulWidget {
  final IconData icon;
  final IconData? activeIcon;
  final Color color;
  final bool active;
  final int count;
  final VoidCallback onTap;

  const ActionButton({
    super.key,
    required this.icon,
    this.activeIcon,
    required this.color,
    this.active = false,
    this.count = 0,
    required this.onTap,
  });

  @override
  State<ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<ActionButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = _p(context);
    final label = widget.count > 0 ? formatCount(widget.count) : '';

    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        _c.forward(from: 0);
        widget.onTap();
      },
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          AnimatedBuilder(
            animation: _c,
            builder: (_, child) {
              final t = _c.value;
              final scale = t < .5 ? 1 + t * .5 : 1.25 - (t - .5) * .5;

              return Transform.scale(scale: scale, child: child);
            },
            child: Icon(
              widget.active ? (widget.activeIcon ?? widget.icon) : widget.icon,
              size: 20,
              color: widget.active ? widget.color : p.sub,
            ),
          ),
          if (label.isNotEmpty) ...[
            const SizedBox(width: 5),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 240),
              child: Text(
                label,
                key: ValueKey('${widget.count}-${widget.active}'),
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: widget.active ? widget.color : p.sub,
                ),
              ),
            ),
          ],
        ]),
      ),
    );
  }
}

class MediaGrid extends StatelessWidget {
  final Post post;

  const MediaGrid({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    final media =
        post.media.where((m) => m.type != 'audio' && m.type != 'file').toList();

    final audios = post.media.where((m) => m.type == 'audio').toList();
    final files = post.media.where((m) => m.type == 'file').toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (media.isNotEmpty) _buildImageVideoGrid(media),
      if (audios.isNotEmpty) ...[
        const SizedBox(height: 8),
        for (final a in audios)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: AudioChip(media: a),
          ),
      ],
      if (files.isNotEmpty) ...[
        const SizedBox(height: 8),
        for (final f in files)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: FileCard(media: f),
          ),
      ],
    ]);
  }

  Widget _buildImageVideoGrid(List<MediaItem> media) {
    if (media.length == 1) {
      final m = media.first;

      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: (m.type == 'video' || m.type == 'gif')
            ? InlineVideo(url: m.url, thumbnail: m.thumbnail, type: m.type)
            : _MediaImage(media: m, heroTag: 'media_${post.id}_0', height: 230),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Column(
          children: [
            if (media.length == 2) _buildTwoLayout(media),
            if (media.length == 3) _buildThreeLayout(media),
            if (media.length >= 4) _buildFourOrMoreLayout(media),
          ],
        ),
      ),
    );
  }

  Widget _buildTwoLayout(List<MediaItem> media) {
    return SizedBox(
      height: 190,
      child: Row(
        children: [
          Expanded(
            child: _MediaImage(
              media: media[0],
              heroTag: 'media_${post.id}_0',
              height: 190,
            ),
          ),
          const SizedBox(width: 2),
          Expanded(
            child: _MediaImage(
              media: media[1],
              heroTag: 'media_${post.id}_1',
              height: 190,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThreeLayout(List<MediaItem> media) {
    return SizedBox(
      height: 150,
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: _MediaImage(
              media: media[0],
              heroTag: 'media_${post.id}_0',
              height: 150,
            ),
          ),
          const SizedBox(width: 2),
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: _MediaImage(
                    media: media[1],
                    heroTag: 'media_${post.id}_1',
                    height: 74,
                  ),
                ),
                const SizedBox(height: 2),
                Expanded(
                  child: _MediaImage(
                    media: media[2],
                    heroTag: 'media_${post.id}_2',
                    height: 74,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFourOrMoreLayout(List<MediaItem> media) {
    return SizedBox(
      height: 150,
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: _MediaImage(
                    media: media[0],
                    heroTag: 'media_${post.id}_0',
                    height: 74,
                  ),
                ),
                const SizedBox(width: 2),
                Expanded(
                  child: _MediaImage(
                    media: media[1],
                    heroTag: 'media_${post.id}_1',
                    height: 74,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: _MediaImage(
                    media: media[2],
                    heroTag: 'media_${post.id}_2',
                    height: 74,
                  ),
                ),
                const SizedBox(width: 2),
                Expanded(
                  child: Stack(
                    children: [
                      _MediaImage(
                        media: media[3],
                        heroTag: 'media_${post.id}_3',
                        height: 74,
                      ),
                      if (media.length > 4)
                        Positioned.fill(
                          child: Container(
                            color: Colors.black.withOpacity(0.55),
                            child: Center(
                              child: Text(
                                '+${media.length - 4}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MediaImage extends StatelessWidget {
  final MediaItem media;
  final String heroTag;
  final double height;

  const _MediaImage({
    required this.media,
    required this.heroTag,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final p = _p(context);
    final imageUrl = media.thumbnail ?? media.url;

    return GestureDetector(
      onTap: () {
        if (media.type == 'video' || media.type == 'gif') {
          Navigator.push(
            context,
            FadeRoute(FullScreenVideoScreen(url: media.url, thumbnail: media.thumbnail)),
          );
        } else {
          Navigator.push(
            context,
            FadeRoute(MediaViewerScreen(media: media, heroTag: heroTag)),
          );
        }
      },
      child: Hero(
        tag: heroTag,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: SizedBox(
            width: double.infinity,
            height: height,
            child: Stack(fit: StackFit.expand, children: [
              CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) => Shimmer.fromColors(
                  baseColor: p.card,
                  highlightColor: p.card2,
                  child: Container(color: p.card),
                ),
                errorWidget: (_, __, ___) => Container(
                  color: p.card,
                  child: Icon(
                    Icons.image_not_supported_outlined,
                    color: p.sub,
                    size: 30,
                  ),
                ),
              ),
              if (media.type == 'video' || media.type == 'gif')
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(.55),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 38,
                    ),
                  ),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}

class FileCard extends StatefulWidget {
  final MediaItem media;

  const FileCard({super.key, required this.media});

  @override
  State<FileCard> createState() => _FileCardState();
}

class _FileCardState extends State<FileCard> {
  double _progress = 0;
  bool _downloading = false;
  bool _done = false;
  String? _savedPath;

  @override
  void initState() {
    super.initState();
    _checkCache();
  }

  Future<void> _checkCache() async {
    final fullUrl = _fullUrl(widget.media.url);
    final cached = await FileCache.instance.hasFile(fullUrl);

    if (cached && mounted) {
      setState(() {
        _done = true;
        _savedPath = FileCache.instance.getLocalPath(fullUrl);
      });
    }
  }

  Future<void> _download() async {
    if (_downloading) return;

    try {
      final status = await Permission.storage.request();

      if (!status.isGranted && Platform.isAndroid) {
        final s2 = await Permission.manageExternalStorage.request();

        if (!s2.isGranted) {
          if (mounted) showSnack(context, 'Storage permission required', error: true);
          return;
        }
      }
    } catch (_) {}

    setState(() {
      _downloading = true;
      _progress = 0;
      _done = false;
    });

    final fullUrl = _fullUrl(widget.media.url);

    try {
      final path = await FileCache.instance.downloadWithResume(
        fullUrl,
        onProgress: (v) {
          if (mounted) setState(() => _progress = v);
        },
        headers: authHeaders(),
      );

      if (!mounted) return;

      setState(() {
        _downloading = false;
        _done = true;
        _savedPath = path;
      });

      showSnack(context, 'Download complete ✓');
      OpenFile.open(path);
    } catch (e) {
      if (mounted) {
        setState(() => _downloading = false);
        showSnack(context, 'Download failed: $e', error: true);
      }
    }
  }

  IconData _fileIcon() {
    final name = widget.media.originalName?.toLowerCase() ?? '';
    final mime = widget.media.mimeType?.toLowerCase() ?? '';

    if (mime.contains('pdf') || name.endsWith('.pdf')) {
      return Icons.picture_as_pdf_rounded;
    }

    if (mime.contains('word') || name.endsWith('.doc') || name.endsWith('.docx')) {
      return Icons.description_rounded;
    }

    if (mime.contains('zip') || mime.contains('rar') || name.contains('.zip')) {
      return Icons.folder_zip_rounded;
    }

    if (mime.contains('text') || name.endsWith('.txt')) return Icons.article_rounded;

    return Icons.attach_file_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final p = _p(context);

    final name = widget.media.originalName?.isNotEmpty == true
        ? widget.media.originalName!
        : 'File';

    final fullUrl = _fullUrl(widget.media.url);

    final cacheProgress = FileCache.instance.getProgress(fullUrl);
    final isCacheActive = FileCache.instance.isDownloading(fullUrl);
    final displayProgress = _progress > 0 ? _progress : cacheProgress;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.border),
      ),
      child: Row(children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: p.accent.withOpacity(.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(_fileIcon(), color: p.accent, size: 28),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            const SizedBox(height: 4),
            if (_downloading || isCacheActive)
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                LinearProgressIndicator(
                  value: displayProgress,
                  color: p.accent,
                  backgroundColor: p.card2,
                ),
                const SizedBox(height: 3),
                Text(
                  '${(displayProgress * 100).toInt()}%',
                  style: TextStyle(fontSize: 11, color: p.sub),
                ),
              ])
            else if (_done && _savedPath != null)
              GestureDetector(
                onTap: () => OpenFile.open(_savedPath),
                child: Row(children: [
                  Icon(Icons.check_circle_rounded, color: p.green, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    'Downloaded — tap to open',
                    style: TextStyle(fontSize: 11, color: p.green),
                  ),
                ]),
              )
            else
              Text(
                'Tap download to save',
                style: TextStyle(fontSize: 11, color: p.sub),
              ),
          ]),
        ),
        GestureDetector(
          onTap: _done && _savedPath != null ? () => OpenFile.open(_savedPath) : _download,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: p.brand,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: p.accent.withOpacity(.3), blurRadius: 10)
              ],
            ),
            child: Icon(
              _downloading
                  ? Icons.hourglass_top_rounded
                  : (_done ? Icons.open_in_new_rounded : Icons.download_rounded),
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      ]),
    );
  }
}

class InlineVideo extends StatefulWidget {
  final String url;
  final String? thumbnail;
  final String type;

  const InlineVideo({
    super.key,
    required this.url,
    this.thumbnail,
    this.type = 'video',
  });

  @override
  State<InlineVideo> createState() => _InlineVideoState();
}

class _InlineVideoState extends State<InlineVideo> {
  VideoPlayerController? _c;

  bool _initializing = false;
  bool _error = false;
  bool _started = false;

  Future<void> _toggle() async {
    if (_error) return;

    HapticFeedback.selectionClick();

    if (!_started) {
      setState(() {
        _initializing = true;
        _started = true;
      });

      final c = VideoPlayerController.networkUrl(Uri.parse(widget.url));
      _c = c;

      await c.initialize().catchError((_) {
        if (mounted) setState(() => _error = true);
      });

      if (!mounted || _error) return;

      c.setLooping(true);
      c.setVolume(1);

      AudioController.instance.muteTemporarily();
      await c.play();

      setState(() => _initializing = false);
    } else if (_c != null) {
      setState(() {
        if (_c!.value.isPlaying) {
          _c!.pause();
        } else {
          _c!.play();
        }
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final tab = context.read<AppState>().currentTab.value;

    if (tab != 0 && _c != null && _c!.value.isPlaying) {
      _c!.pause();
    }
  }

  @override
  void dispose() {
    AudioController.instance.unmute();
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = _p(context);

    if (!_started && widget.thumbnail != null && widget.thumbnail!.isNotEmpty) {
      return GestureDetector(
        onTap: _toggle,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(fit: StackFit.expand, children: [
              CachedNetworkImage(
                imageUrl: widget.thumbnail!,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(color: p.card),
                errorWidget: (_, __, ___) => Container(color: p.card),
              ),
              Container(color: Colors.black.withOpacity(.25)),
              Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(.6),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white24),
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
              ),
              Positioned(
                right: 12,
                top: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(.6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      FadeRoute(FullScreenVideoScreen(
                        url: widget.url,
                        thumbnail: widget.thumbnail,
                      )),
                    ),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.fullscreen_rounded, color: Colors.white, size: 16),
                      SizedBox(width: 4),
                      Text(
                        'Full',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
            ]),
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(
          color: Colors.black,
          child: Stack(children: [
            if (_c != null && _c!.value.isInitialized)
              Positioned.fill(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _c!.value.size.width,
                    height: _c!.value.size.height,
                    child: VideoPlayer(_c!),
                  ),
                ),
              ),
            GestureDetector(onTap: _toggle, behavior: HitTestBehavior.opaque),
            if (_initializing)
              const Center(child: CircularProgressIndicator(strokeWidth: 2.6)),
            if (_error)
              Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.videocam_off_rounded, color: p.sub, size: 34),
                  const SizedBox(height: 6),
                  Text('Video unavailable', style: TextStyle(color: p.sub, fontSize: 12)),
                ]),
              ),
            if (_c != null && !_c!.value.isPlaying && !_initializing && !_error)
              Center(
                child: Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(.55),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white24),
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 36,
                  ),
                ),
              ),
            if (_c != null && _c!.value.isInitialized) ...[
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: VideoProgressIndicator(
                  _c!,
                  allowScrubbing: true,
                  colors: VideoProgressColors(
                    playedColor: p.accent,
                    bufferedColor: Colors.white24,
                    backgroundColor: Colors.white10,
                  ),
                ),
              ),
              Positioned(
                right: 8,
                top: 8,
                child: GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    FadeRoute(FullScreenVideoScreen(
                      url: widget.url,
                      thumbnail: widget.thumbnail,
                    )),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(.6),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.fullscreen_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}

class PostCard extends StatefulWidget {
  final Post post;
  final bool detail;
  final VoidCallback? onChanged;
  final VoidCallback? onDeleted;

  const PostCard({
    super.key,
    required this.post,
    this.detail = false,
    this.onChanged,
    this.onDeleted,
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  final _api = ApiClient.instance;

  Post get displayPost => widget.post.repostOf ?? widget.post;

  void _toggleLike() {
    setState(() {
      displayPost.liked = !displayPost.liked;
      displayPost.likeCount += displayPost.liked ? 1 : -1;
    });

    widget.onChanged?.call();
    _api.post('/api/posts/${displayPost.id}/like').catchError((_) {});
  }

  void _toggleRetweet() {
    setState(() {
      displayPost.retweeted = !displayPost.retweeted;
      displayPost.retweetCount += displayPost.retweeted ? 1 : -1;
    });

    widget.onChanged?.call();
    _api.post('/api/posts/${displayPost.id}/retweet').catchError((_) {});
  }

  void _toggleBookmark() {
    setState(() => displayPost.bookmarked = !displayPost.bookmarked);

    widget.onChanged?.call();
    showSnack(
      context,
      displayPost.bookmarked ? 'Added to bookmarks 🔖' : 'Removed bookmark',
    );

    _api.post('/api/posts/${displayPost.id}/bookmark').catchError((_) {});
  }

  void _openDetail() {
    if (widget.detail) return;

    Navigator.push(
      context,
      FadeRoute(PostDetailScreen(postId: displayPost.id, initial: displayPost)),
    );
  }

  void _openAuthorProfile() {
    final u = displayPost.author?.username;
    if (u == null || u.isEmpty) return;

    Navigator.push(context, FadeRoute(ProfileScreen(username: u)));
  }

  Future<void> _openAuthorAvatar() async {
    final author = displayPost.author;
    if (author == null) return;

    if (author.id != null && author.hasUnseenStory) {
      await Navigator.push(
        context,
        FadeRoute(StoryViewerScreen(userId: author.id!, user: author)),
      );

      if (!mounted) return;

      setState(() {
        widget.post.author = widget.post.author?.copyWithUnseenStory(false);
        widget.post.repostOf?.author =
            widget.post.repostOf?.author?.copyWithUnseenStory(false);
      });

      widget.onChanged?.call();
    } else {
      _openAuthorProfile();
    }
  }

  Future<void> _delete() async {
    final p = _p(context);

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: p.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text(
          'Delete post?',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        content: const Text(
          'This cannot be undone.',
          style: TextStyle(fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: p.sub)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Delete',
              style: TextStyle(color: p.red, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await _api.delete('/api/posts/${displayPost.id}');

      if (mounted) {
        showSnack(context, 'Post deleted');
        widget.onDeleted?.call();
      }
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    }
  }

  void _menu() {
    final p = _p(context);
    final me = context.read<AppState>().me;

    final own = me != null &&
        displayPost.author != null &&
        me.username == displayPost.author!.username;

    showModalBottomSheet(
      context: context,
      backgroundColor: p.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            margin: const EdgeInsets.only(top: 10),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: p.border,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          if (own)
            _mItem(Icons.edit_outlined, 'Edit post', p.accent, () {
              Navigator.pop(ctx);

              Navigator.push(
                context,
                SlideUpRoute(
                  ComposeScreen(
                    editPost: displayPost,
                    onDone: () => widget.onChanged?.call(),
                  ),
                ),
              ).then((_) => widget.onChanged?.call());
            }),
          _mItem(Icons.copy_rounded, 'Copy text', p.text, () {
            Navigator.pop(ctx);
            Clipboard.setData(ClipboardData(text: displayPost.text));
            showSnack(context, 'Copied to clipboard');
          }),
          _mItem(
            displayPost.bookmarked
                ? Icons.bookmark_remove_rounded
                : Icons.bookmark_add_rounded,
            displayPost.bookmarked ? 'Remove bookmark' : 'Bookmark',
            p.gold,
            () {
              Navigator.pop(ctx);
              _toggleBookmark();
            },
          ),
          if (own)
            _mItem(Icons.delete_outline_rounded, 'Delete post', p.red, () {
              Navigator.pop(ctx);
              _delete();
            }),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  Widget _mItem(IconData icon, String label, Color color, VoidCallback onTap) =>
      ListTile(
        leading: Icon(icon, color: color, size: 22),
        title: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
        onTap: onTap,
      );

  @override
  Widget build(BuildContext context) {
    final p = _p(context);

    final post = widget.post;
    final author = post.author;
    final isRepost = post.repostOf != null;

    String? likedByText;

    if (post.likedByFollowings.isNotEmpty) {
      final names = post.likedByFollowings.take(2).map((e) => '@$e').toList();

      likedByText =
          'Liked by ${names.join(', ')}${post.likedByFollowings.length > 2 ? ' and others' : ''}';
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (isRepost && post.repostedByFollowings.isNotEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(children: [
            Icon(Icons.repeat_rounded, color: p.green, size: 14),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                '${post.repostedByFollowings.take(2).map((e) => '@$e').join(', ')} reposted',
                style: TextStyle(
                  fontSize: 12,
                  color: p.sub,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ]),
        ),
      if (isRepost && post.repostedByFollowings.isEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(64, 10, 16, 0),
          child: GestureDetector(
            onTap: _openAuthorProfile,
            child: Row(children: [
              Icon(Icons.repeat_rounded, color: p.green, size: 14),
              const SizedBox(width: 6),
              Text(
                '${author?.displayName ?? 'Someone'} reposted',
                style: TextStyle(fontSize: 12, color: p.sub, fontWeight: FontWeight.w600),
              ),
            ]),
          ),
        ),
      InkWell(
        onTap: _openDetail,
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 14, 16, widget.detail ? 4 : 10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            GestureDetector(
              onTap: _openAuthorAvatar,
              child: Avatar(
                url: displayPost.author?.avatarUrl,
                size: widget.detail ? 48 : 44,
                ring: displayPost.author?.hasUnseenStory ?? false,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Flexible(
                    child: GestureDetector(
                      onTap: _openAuthorProfile,
                      child: Text(
                        displayPost.author?.displayName ?? 'Unknown',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: p.text,
                        ),
                      ),
                    ),
                  ),
                  if (displayPost.author?.verified ?? false) ...[
                    const SizedBox(width: 4),
                    Icon(Icons.verified_rounded, size: 16, color: p.accent),
                  ],
                  if (displayPost.author != null) ...[
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        '@${displayPost.author!.username} · ${timeAgo(context, displayPost.createdAt)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: p.sub, fontSize: 13),
                      ),
                    ),
                  ],
                  const Spacer(),
                  GestureDetector(
                    onTap: _menu,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(Icons.more_horiz_rounded, size: 19, color: p.sub),
                    ),
                  ),
                ]),
                if (displayPost.text.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      displayPost.text,
                      maxLines: widget.detail ? null : 12,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: widget.detail ? 17 : 14.5,
                        height: 1.38,
                        color: p.text,
                      ),
                    ),
                  ),
                MediaGrid(post: displayPost),
                if (displayPost.quoted != null) QuoteCard(post: displayPost.quoted!),
                const SizedBox(height: 6),
                Row(children: [
                  ActionButton(
                    icon: Icons.chat_bubble_outline_rounded,
                    color: p.accent,
                    count: displayPost.replyCount,
                    onTap: _openDetail,
                  ),
                  const Spacer(),
                  ActionButton(
                    icon: Icons.repeat_rounded,
                    color: p.green,
                    active: displayPost.retweeted,
                    count: displayPost.retweetCount,
                    onTap: _toggleRetweet,
                  ),
                  const Spacer(),
                  ActionButton(
                    icon: Icons.favorite_border_rounded,
                    activeIcon: Icons.favorite_rounded,
                    color: p.pink,
                    active: displayPost.liked,
                    count: displayPost.likeCount,
                    onTap: _toggleLike,
                  ),
                  const Spacer(),
                  ActionButton(
                    icon: Icons.bookmark_border_rounded,
                    activeIcon: Icons.bookmark_rounded,
                    color: p.accent,
                    active: displayPost.bookmarked,
                    onTap: _toggleBookmark,
                  ),
                ]),
                if (likedByText != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      likedByText,
                      style: TextStyle(
                        fontSize: 12,
                        color: p.sub,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
              ]),
            ),
          ]),
        ),
      ),
    ]);
  }
}

class QuoteCard extends StatelessWidget {
  final Post post;

  const QuoteCard({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    final p = _p(context);

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        FadeRoute(PostDetailScreen(postId: post.id, initial: post)),
      ),
      child: Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: p.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: p.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          GestureDetector(
            onTap: () => openUserOrStory(context, post.author),
            child: Row(children: [
              Avatar(
                url: post.author?.avatarUrl,
                size: 22,
                ring: post.author?.hasUnseenStory ?? false,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  '${post.author?.displayName ?? 'Unknown'}  ·  ${timeAgo(context, post.createdAt)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
              ),
            ]),
          ),
          if (post.text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                post.text,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13.5, height: 1.3),
              ),
            ),
          if (post.media.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  height: 120,
                  width: double.infinity,
                  child: (post.media.first.type == 'video' ||
                          post.media.first.type == 'gif')
                      ? (post.media.first.thumbnail != null
                          ? Stack(fit: StackFit.expand, children: [
                              CachedNetworkImage(
                                imageUrl: post.media.first.thumbnail!,
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) => Container(color: p.card),
                              ),
                              const Center(
                                child: Icon(
                                  Icons.play_circle_fill_rounded,
                                  color: Colors.white70,
                                  size: 40,
                                ),
                              ),
                            ])
                          : Container(
                              color: Colors.black,
                              child: const Center(
                                child: Icon(
                                  Icons.play_circle_fill_rounded,
                                  color: Colors.white70,
                                  size: 40,
                                ),
                              ),
                            ))
                      : CachedNetworkImage(
                          imageUrl:
                              post.media.first.thumbnail ?? post.media.first.url,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Container(color: p.card),
                        ),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}

class AudioChip extends StatefulWidget {
  final MediaItem media;

  const AudioChip({super.key, required this.media});

  @override
  State<AudioChip> createState() => _AudioChipState();
}

class _AudioChipState extends State<AudioChip> {
  bool _cached = false;

  @override
  void initState() {
    super.initState();
    _checkCache();
  }

  String get _title => widget.media.title?.isNotEmpty == true
      ? widget.media.title!
      : (widget.media.originalName?.isNotEmpty == true
          ? widget.media.originalName!
          : 'Audio track');

  Future<void> _checkCache() async {
    final full = _fullUrl(widget.media.url);

    if (await FileCache.instance.hasFile(full)) {
      if (mounted) setState(() => _cached = true);
    }
  }

  Future<void> _play() async {
    final audio = AudioController.instance;
    final full = _fullUrl(widget.media.url);

    if (audio.currentKey == widget.media.url) {
      if (audio.playing) {
        await audio.pause();
      } else {
        await audio.resume();
      }
      return;
    }

    try {
      String path;

      if (await FileCache.instance.hasFile(full)) {
        path = FileCache.instance.getLocalPath(full);

        if (!_cached && mounted) {
          setState(() => _cached = true);
        }
      } else {
        path = await FileCache.instance.downloadWithResume(
          full,
          headers: authHeaders(),
          onProgress: (_) {
            if (mounted) setState(() {});
          },
        );

        if (mounted) setState(() => _cached = true);
      }

      await audio.play(
        path,
        key: widget.media.url,
        title: _title,
        artist: widget.media.artist,
        duration: widget.media.duration,
      );
    } catch (_) {
      if (mounted) showSnack(context, 'Audio playback failed', error: true);
    }
  }

  Future<void> _downloadOnly() async {
    final full = _fullUrl(widget.media.url);

    try {
      await FileCache.instance.downloadWithResume(
        full,
        headers: authHeaders(),
        onProgress: (_) {
          if (mounted) setState(() {});
        },
      );

      if (mounted) {
        setState(() => _cached = true);
        showSnack(context, 'Download complete ✓');
      }
    } catch (_) {
      if (mounted) showSnack(context, 'Download failed', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _p(context);
    final audio = context.watch<AudioController>();
    final cache = context.watch<FileCache>();

    final isCurrent = audio.currentKey == widget.media.url;
    final isPlaying = isCurrent && audio.playing;

    final fullUrl = _fullUrl(widget.media.url);
    final dlProgress = cache.getProgress(fullUrl);
    final isDlActive = cache.isDownloading(fullUrl);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.border),
      ),
      child: Column(children: [
        Row(children: [
          GestureDetector(
            onTap: _play,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: p.brand,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: p.accent.withOpacity(.3), blurRadius: 8)
                ],
              ),
              child: Icon(
                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
          if (!_cached) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: isDlActive ? null : _downloadOnly,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: p.accent.withOpacity(.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: isDlActive
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          value: dlProgress,
                          color: p.accent,
                        ),
                      )
                    : Icon(Icons.download_rounded, color: p.accent, size: 18),
              ),
            ),
          ],
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Row(children: [
                  if (widget.media.artist?.isNotEmpty == true)
                    Expanded(
                      child: Text(
                        widget.media.artist!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: p.sub),
                      ),
                    ),
                  if (widget.media.duration != null) ...[
                    if (widget.media.artist?.isNotEmpty == true)
                      const SizedBox(width: 6),
                    Text(
                      formatDuration(widget.media.duration),
                      style: TextStyle(fontSize: 11, color: p.sub),
                    ),
                  ],
                ]),
              ],
            ),
          ),
        ]),
        if (isDlActive && !_cached)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(children: [
              Expanded(
                child: LinearProgressIndicator(
                  value: dlProgress,
                  color: p.accent,
                  backgroundColor: p.card2,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${(dlProgress * 100).toInt()}%',
                style: TextStyle(fontSize: 10, color: p.sub),
              ),
            ]),
          ),
        if (isCurrent) ...[
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              activeTrackColor: p.accent,
              inactiveTrackColor: p.card2,
              thumbColor: p.accent,
            ),
            child: Slider(
              value: audio.position.clamp(0.0, audio.currentDuration ?? 1.0),
              max: audio.currentDuration ?? 1.0,
              onChanged: (v) => audio.seekTo(v),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(
                formatDuration(audio.position),
                style: TextStyle(fontSize: 10, color: p.sub),
              ),
              Text(
                formatDuration(audio.currentDuration),
                style: TextStyle(fontSize: 10, color: p.sub),
              ),
            ]),
          ),
        ],
      ]),
    );
  }
}

// ═══════════════════════════════ COMPOSE ══════════════════════════
class _PendingMedia {
  final String path;
  final String? name;
  final String mediaKind;

  String? id;
  String? url;
  String? thumbnail;

  bool uploading = true;
  bool error = false;
  double progress = 0;

  _PendingMedia(this.path, this.mediaKind, {this.name});
}

class ComposeScreen extends StatefulWidget {
  final Post? parentPost;
  final Post? quotedPost;
  final Post? editPost;
  final VoidCallback? onDone;

  const ComposeScreen({
    super.key,
    this.parentPost,
    this.quotedPost,
    this.editPost,
    this.onDone,
  });

  @override
  State<ComposeScreen> createState() => _ComposeScreenState();
}

class _ComposeScreenState extends State<ComposeScreen> {
  final _api = ApiClient.instance;
  final _text = TextEditingController();
  final _picker = ImagePicker();

  final List<_PendingMedia> _media = [];

  bool _posting = false;
  static const int _limit = 500;

  List<User> _mentions = [];
  bool _mentionLoading = false;
  int _mentionStart = -1;
  String _mentionToken = '';
  Timer? _mentionTimer;

  @override
  void initState() {
    super.initState();

    _text.addListener(_onTextChanged);

    if (widget.editPost != null) {
      _text.text = widget.editPost!.text;

      for (final m in widget.editPost!.media) {
        _media.add(_PendingMedia('', m.type, name: m.originalName)
          ..id = m.id ?? m.url
          ..url = m.url
          ..thumbnail = m.thumbnail
          ..uploading = false
          ..progress = 1.0);
      }
    }
  }

  @override
  void dispose() {
    _text.removeListener(_onTextChanged);
    _mentionTimer?.cancel();
    _text.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    if (mounted) setState(() {});
    _updateMentionState();
  }

  void _updateMentionState() {
    final text = _text.text;

    int pos = _text.selection.baseOffset;
    if (pos < 0 || pos > text.length) pos = text.length;

    final before = text.substring(0, pos);
    final at = before.lastIndexOf('@');

    if (at >= 0) {
      final token = before.substring(at + 1);

      if (!token.contains(' ') && !token.contains('\n')) {
        _mentionStart = at;
        _mentionToken = token;
        _fetchMentions(token);
        return;
      }
    }

    _mentionStart = -1;
    _mentionToken = '';
    _mentions = [];
  }

  void _fetchMentions(String q) {
    _mentionTimer?.cancel();

    _mentionTimer = Timer(const Duration(milliseconds: 250), () async {
      if (!mounted) return;

      setState(() => _mentionLoading = true);

      try {
        final res = await _api.get('/api/users', query: {
          if (q.isNotEmpty) 'q': q,
          'limit': '20',
        });

        if (!mounted) return;

        setState(() {
          _mentions = extractItems(res).map(User.fromJson).toList();
          _mentionLoading = false;
        });
      } catch (_) {
        if (mounted) setState(() => _mentionLoading = false);
      }
    });
  }

  void _insertMention(User u) {
    final text = _text.text;

    int end = _text.selection.baseOffset;
    if (end < 0 || end > text.length) end = text.length;

    if (_mentionStart < 0 || _mentionStart > end) return;

    final insert = '@${u.username} ';
    final newText = text.replaceRange(_mentionStart, end, insert);

    _text.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: _mentionStart + insert.length,
      ),
    );

    setState(() {
      _mentionStart = -1;
      _mentionToken = '';
      _mentions = [];
    });
  }

  Future<void> _pickImage({bool camera = false}) async {
    final f = await _picker.pickImage(
      source: camera ? ImageSource.camera : ImageSource.gallery,
      imageQuality: 85,
    );

    if (f == null) return;

    _addAndUpload(f.path, 'image', name: f.name);
  }

  Future<void> _pickVideo({bool camera = false}) async {
    final f = await _picker.pickVideo(
      source: camera ? ImageSource.camera : ImageSource.gallery,
      maxDuration: const Duration(minutes: 3),
    );

    if (f == null) return;

    _addAndUpload(f.path, 'video', name: f.name);
  }

  Future<void> _pickAudio() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.audio);

    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    if (file.path == null) return;

    _addAndUpload(file.path!, 'audio', name: file.name);
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.any);

    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    if (file.path == null) return;

    final mime = lookupMimeType(file.path!) ?? '';

    final kind = mime.startsWith('video/')
        ? 'video'
        : mime.startsWith('audio/')
            ? 'audio'
            : mime.startsWith('image/')
                ? 'image'
                : 'file';

    _addAndUpload(file.path!, kind, name: file.name);
  }

  void _addAndUpload(String path, String kind, {String? name}) {
    final pm = _PendingMedia(path, kind, name: name);
    setState(() => _media.add(pm));
    _upload(pm);
  }

  Future<void> _upload(_PendingMedia pm) async {
    try {
      final res = await _api.uploadMedia(
        pm.path,
        onProgress: (v) {
          if (mounted) setState(() => pm.progress = v);
        },
      );

      String id = '';
      String? url, thumb;

      if (res is Map) {
        id = jstr(jpick(res, ['id', 'media_id']));
        url = resolveMedia(jpick(res, ['url', 'file_url']));
        thumb = resolveMedia(jpick(res, ['thumbnail', 'thumb']));
      }

      if (!mounted) return;

      setState(() {
        pm.id = id.isNotEmpty ? id : null;
        pm.url = url;
        pm.thumbnail = thumb;
        pm.uploading = false;
        pm.progress = 1.0;
        pm.error = id.isEmpty;
      });

      if (id.isEmpty && mounted) {
        showSnack(context, 'Upload failed', error: true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          pm.uploading = false;
          pm.error = true;
        });

        showSnack(context, 'Upload error: $e', error: true);
      }
    }
  }

  Future<void> _submit() async {
    if (_posting) return;

    final text = _text.text.trim();

    if (_media.any((m) => m.uploading)) {
      if (mounted) showSnack(context, 'Wait for uploads to finish…');
      return;
    }

    final validMedia = _media.where((m) => !m.error && m.id != null).toList();

    if (text.isEmpty && validMedia.isEmpty) {
      if (mounted) showSnack(context, 'Write something or add media', error: true);
      return;
    }

    setState(() => _posting = true);

    try {
      final ids = validMedia.map((m) => m.id!).toList();

      final body = <String, dynamic>{
        'text': text,
        if (ids.isNotEmpty) 'media_ids': ids,
        if (widget.parentPost?.id != null) 'parent_id': widget.parentPost!.id,
        if (widget.quotedPost?.id != null)
          'quoted_post_id': widget.quotedPost!.id,
      };

      if (widget.editPost != null) {
        await _api.put('/api/posts/${widget.editPost!.id}', body: body);
      } else {
        await _api.post('/api/posts', body: body);
      }

      context.read<AppState>().pokeFeed();
      widget.onDone?.call();

      if (mounted) {
        showSnack(
          context,
          widget.editPost != null ? 'Post updated ✨' : 'Posted! 🎉',
        );

        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint('Post error: $e');
      if (mounted) showSnack(context, 'Error: $e', error: true);
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  IconData _iconFor(String kind) {
    if (kind == 'video') return Icons.videocam_rounded;
    if (kind == 'audio') return Icons.audiotrack_rounded;
    if (kind == 'file') return Icons.attach_file_rounded;
    return Icons.image_rounded;
  }

  @override
  Widget build(BuildContext context) {
    _applyBars(context);

    final p = _p(context);
    final me = context.watch<AppState>().me;

    final remaining = _limit - _text.text.length;
    final hasText = _text.text.trim().isNotEmpty;
    final validMediaCount = _media.where((m) => !m.error && m.id != null).length;

    final canPost = !_posting && remaining >= 0 && (hasText || validMediaCount > 0);

    return Scaffold(
      backgroundColor: p.bg,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: p.sub),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GradientButton(
              text: widget.editPost != null ? 'Save' : 'Post',
              width: 96,
              height: 40,
              loading: _posting,
              onPressed: canPost ? _submit : null,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (widget.parentPost != null)
              _banner(
                Icons.reply_rounded,
                'Replying to @${widget.parentPost!.author?.username ?? ''}',
              ),
            if (widget.quotedPost != null)
              _banner(Icons.format_quote_rounded, 'Quote post'),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Avatar(
                url: me?.avatarUrl,
                size: 44,
                ring: me?.hasUnseenStory ?? false,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _text,
                  autofocus: true,
                  maxLines: null,
                  minLines: 6,
                  style: TextStyle(fontSize: 17, height: 1.4, color: p.text),
                  decoration: InputDecoration(
                    hintText: widget.parentPost != null
                        ? 'Post your reply…'
                        : "What's happening?",
                    hintStyle: TextStyle(color: p.sub),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ]),
            if (_mentionStart >= 0)
              Container(
                margin: const EdgeInsets.only(top: 8),
                height: 180,
                decoration: BoxDecoration(
                  color: p.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: p.border),
                ),
                child: _mentionLoading
                    ? const Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.2),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        itemCount: _mentions.length,
                        separatorBuilder: (_, __) => Divider(
                          height: 1,
                          color: p.border.withOpacity(.5),
                        ),
                        itemBuilder: (context, i) {
                          final u = _mentions[i];

                          return ListTile(
                            dense: true,
                            onTap: () => _insertMention(u),
                            leading: Avatar(url: u.avatarUrl, size: 32),
                            title: Text(
                              u.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13.5,
                              ),
                            ),
                            subtitle: Text(
                              '@${u.username}',
                              style: TextStyle(color: p.sub, fontSize: 12),
                            ),
                          );
                        },
                      ),
              ),
            if (widget.quotedPost != null) QuoteCard(post: widget.quotedPost!),
            if (_media.isNotEmpty) ...[
              const SizedBox(height: 10),
              SizedBox(
                height: 130,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _media.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final m = _media[i];

                    return Stack(children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: SizedBox(
                          width: 110,
                          height: 130,
                          child: m.url != null && m.url!.isNotEmpty
                              ? (m.mediaKind == 'audio'
                                  ? Container(
                                      color: p.card,
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.audiotrack_rounded,
                                              color: p.accent, size: 34),
                                          const SizedBox(height: 4),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                            ),
                                            child: Text(
                                              m.name ?? 'Audio',
                                              style: TextStyle(fontSize: 10, color: p.sub),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  : (m.thumbnail != null && m.thumbnail!.isNotEmpty
                                      ? CachedNetworkImage(
                                          imageUrl: m.thumbnail!,
                                          fit: BoxFit.cover,
                                          errorWidget: (_, __, ___) => Container(
                                            color: p.card,
                                            child: Icon(
                                              _iconFor(m.mediaKind),
                                              color: p.sub,
                                              size: 34,
                                            ),
                                          ),
                                        )
                                      : (m.mediaKind == 'image' && m.path.isNotEmpty
                                          ? Image.file(File(m.path), fit: BoxFit.cover)
                                          : Container(
                                              color: p.card,
                                              child: Center(
                                                child: Icon(
                                                  _iconFor(m.mediaKind),
                                                  color: p.sub,
                                                  size: 34,
                                                ),
                                              ),
                                            ))))
                              : Container(
                                  color: p.card,
                                  child: Center(
                                    child: Icon(
                                      _iconFor(m.mediaKind),
                                      color: p.sub,
                                      size: 34,
                                    ),
                                  ),
                                ),
                        ),
                      ),
                      if (m.uploading)
                        Positioned.fill(
                          child: Container(
                            color: Colors.black.withOpacity(.55),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 30,
                                    height: 30,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.4,
                                      value: m.progress,
                                      color: p.accent,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${(m.progress * 100).toInt()}%',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      if (m.error)
                        Positioned.fill(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                m.uploading = true;
                                m.error = false;
                                m.progress = 0;
                              });

                              _upload(m);
                            },
                            child: Container(
                              color: Colors.black.withOpacity(.6),
                              child: const Center(
                                child: Icon(Icons.refresh_rounded, color: Colors.red, size: 28),
                              ),
                            ),
                          ),
                        ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () => setState(() => _media.removeAt(i)),
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(.65),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ]);
                  },
                ),
              ),
            ],
          ]),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 10, 8),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: p.border)),
          ),
          child: Row(children: [
            IconButton(
              onPressed: _pickImage,
              icon: Icon(Icons.photo_library_rounded, color: p.accent, size: 24),
            ),
            IconButton(
              onPressed: () => _pickImage(camera: true),
              icon: Icon(Icons.photo_camera_rounded, color: p.accent, size: 24),
            ),
            IconButton(
              onPressed: _pickVideo,
              icon: Icon(Icons.videocam_rounded, color: p.accent, size: 24),
            ),
            IconButton(
              onPressed: _pickAudio,
              icon: Icon(Icons.audiotrack_rounded, color: p.accent, size: 24),
            ),
            IconButton(
              onPressed: _pickFile,
              icon: Icon(Icons.attach_file_rounded, color: p.accent, size: 24),
            ),
            const Spacer(),
            AnimatedOpacity(
              opacity: _text.text.isEmpty ? 0 : 1,
              duration: const Duration(milliseconds: 200),
              child: Text(
                '$remaining',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: remaining < 0
                      ? p.red
                      : remaining < 30
                          ? p.gold
                          : p.sub,
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _banner(IconData icon, String label) {
    final p = _p(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: p.accent.withOpacity(.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.accent.withOpacity(.3)),
      ),
      child: Row(children: [
        Icon(icon, size: 18, color: p.accent),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(color: p.accent, fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════ POST DETAIL ═════════════════════
class PostDetailScreen extends StatefulWidget {
  final int? postId;
  final Post? initial;

  const PostDetailScreen({super.key, this.postId, this.initial});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final _api = ApiClient.instance;
  final _reply = TextEditingController();

  Post? _post;
  List<Post> _replies = [];

  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();

    _post = widget.initial;
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        if (widget.postId != null)
          _api.get('/api/posts/${widget.postId}').catchError((_) => null),
        if (widget.postId != null)
          _api
              .get('/api/posts/${widget.postId}/replies', query: {'limit': '50'})
              .catchError((_) => null),
      ]);

      if (!mounted) return;

      setState(() {
        if (results[0] is Map) {
          try {
            _post = Post.fromJson(Map<String, dynamic>.from(results[0]));
          } catch (_) {}
        }

        _replies = extractItems(results[1]).map(Post.fromJson).toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sendReply() async {
    if (_sending || _reply.text.trim().isEmpty) return;

    setState(() => _sending = true);

    try {
      await _api.post('/api/posts', body: {
        'text': _reply.text.trim(),
        'parent_id': _post?.id ?? widget.postId,
      });

      _reply.clear();
      context.read<AppState>().pokeFeed();

      await _load();

      if (mounted) {
        setState(() => _post?.replyCount = (_post?.replyCount ?? 0) + 1);
      }
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _applyBars(context);

    final p = _p(context);
    final me = context.watch<AppState>().me;

    return Scaffold(
      backgroundColor: p.bg,
      appBar: AppBar(
        title: const Text(
          'Post',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _loading && _post == null
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 20),
                  children: [
                    if (_post != null)
                      PostCard(
                        post: _post!,
                        detail: true,
                        onChanged: () => setState(() {}),
                        onDeleted: () => Navigator.pop(context),
                      ),
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2.4),
                        ),
                      ),
                    if (!_loading && _replies.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 30),
                        child: EmptyState(
                          icon: Icons.chat_bubble_outline_rounded,
                          title: 'No replies yet',
                          subtitle: 'Start the conversation!',
                        ),
                      ),
                    ..._replies.map((r) => Column(children: [
                          Divider(
                            height: 1,
                            thickness: 1,
                            color: p.border.withOpacity(.4),
                          ),
                          SlideFadeIn(child: PostCard(post: r)),
                        ])),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
                  decoration: BoxDecoration(
                    color: p.surface,
                    border: Border(top: BorderSide(color: p.border)),
                  ),
                  child: Row(children: [
                    Avatar(url: me?.avatarUrl, size: 36),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _reply,
                        maxLines: 4,
                        minLines: 1,
                        style: TextStyle(fontSize: 14.5, color: p.text),
                        decoration: InputDecoration(
                          hintText: 'Post your reply…',
                          hintStyle: TextStyle(color: p.sub),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 11,
                          ),
                          filled: true,
                          fillColor: p.card,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(22),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GradientButton(
                      text: 'Reply',
                      width: 84,
                      height: 42,
                      loading: _sending,
                      onPressed: _sending ? null : _sendReply,
                    ),
                  ]),
                ),
              ),
            ]),
    );
  }
}

// ═══════════════════════════════ BOOKMARKS ═══════════════════════
class BookmarksScreen extends StatefulWidget {
  const BookmarksScreen({super.key});

  @override
  State<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends State<BookmarksScreen> {
  final _api = ApiClient.instance;

  List<Post> _posts = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await _api.get('/api/bookmarks', query: {'limit': '50'});
      if (!mounted) return;

      setState(() {
        _posts = extractItems(res).map(Post.fromJson).toList();
        _loading = false;
      });
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Could not load.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    _applyBars(context);
    final p = _p(context);

    return Scaffold(
      backgroundColor: p.bg,
      appBar: AppBar(
        title: const Text(
          'Bookmarks',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _loading
          ? ListView(children: const [ShimmerPost(), ShimmerPost()])
          : _error != null
              ? ErrorState(message: _error!, onRetry: _load)
              : _posts.isEmpty
                  ? const EmptyState(
                      icon: Icons.bookmark_outline_rounded,
                      title: 'No bookmarks',
                      subtitle: 'Save posts to read later',
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: p.accent,
                      child: ListView.separated(
                        itemCount: _posts.length,
                        separatorBuilder: (_, __) => Divider(
                          height: 1,
                          thickness: 1,
                          color: p.border.withOpacity(.4),
                        ),
                        itemBuilder: (context, i) {
                          return PostCard(
                            post: _posts[i],
                            onChanged: () => setState(() {}),
                            onDeleted: () => setState(() => _posts.removeAt(i)),
                          );
                        },
                      ),
                    ),
    );
  }
}

// ═══════════════════════════════ SHORTS ══════════════════════════
class ShortsScreen extends StatefulWidget {
  const ShortsScreen({super.key});

  @override
  State<ShortsScreen> createState() => _ShortsScreenState();
}

class _ShortsScreenState extends State<ShortsScreen> {
  final _api = ApiClient.instance;
  final _page = PageController();

  List<Post> _posts = [];
  int _current = 0;

  bool _loading = true;
  bool _loadingMore = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await _api.get('/api/shorts', query: {'limit': '20'});

      final items = extractItems(res)
          .map(Post.fromJson)
          .where((x) => x.media.isNotEmpty)
          .toList();

      if (!mounted) return;

      setState(() {
        _posts = items;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Could not load shorts.';
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore) return;
    _loadingMore = true;

    try {
      final res = await _api.get(
        '/api/shorts',
        query: {'limit': '20', 'offset': '${_posts.length}'},
      );

      final items = extractItems(res)
          .map(Post.fromJson)
          .where((x) => x.media.isNotEmpty)
          .toList();

      if (mounted) setState(() => _posts.addAll(items));
    } catch (_) {}

    _loadingMore = false;
  }

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _applyBars(context);

    return Stack(fit: StackFit.expand, children: [
      Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
        decoration: const BoxDecoration(
          color: Colors.black,
          border: Border(bottom: BorderSide(color: Colors.black12)),
        ),
        child: Row(children: [
          ShaderMask(
            shaderCallback: (b) =>
                Pal(isDark: true).reel.createShader(Offset.zero & b.size),
            child: const Text(
              'Shorts',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white54),
            onPressed: _load,
          ),
        ]),
      ),
      Positioned(
        top: 55,
        left: 0,
        right: 0,
        bottom: 90,
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : _error != null
                ? ErrorState(message: _error!, onRetry: _load)
                : _posts.isEmpty
                    ? const EmptyState(
                        icon: Icons.movie_creation_outlined,
                        title: 'No shorts yet',
                        subtitle: 'Check back soon!',
                      )
                    : PageView.builder(
                        controller: _page,
                        scrollDirection: Axis.vertical,
                        itemCount: _posts.length,
                        onPageChanged: (i) {
                          setState(() => _current = i);
                          if (i >= _posts.length - 2) _loadMore();
                        },
                        itemBuilder: (context, i) => ReelItem(
                          post: _posts[i],
                          active: i == _current,
                        ),
                      ),
      ),
    ]);
  }
}

class ReelItem extends StatefulWidget {
  final Post post;
  final bool active;

  const ReelItem({super.key, required this.post, required this.active});

  @override
  State<ReelItem> createState() => _ReelItemState();
}

class _ReelItemState extends State<ReelItem> with TickerProviderStateMixin {
  VideoPlayerController? _vc;

  bool _videoError = false;
  bool _muted = false;
  bool _holding = false;
  bool _cachingVideo = false;
  double _cacheProgress = 0;

  late final AnimationController _disc;
  late final AnimationController _heartAnim;

  bool get _isVideo =>
      widget.post.media.first.type == 'video' ||
      widget.post.media.first.type == 'gif';

  @override
  void initState() {
    super.initState();

    _disc = AnimationController(vsync: this, duration: const Duration(seconds: 5));

    _heartAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final currentTab = context.read<AppState>().currentTab.value;
    final inReelsTab = currentTab == 2;

    if (widget.active &&
        inReelsTab &&
        _isVideo &&
        _vc == null &&
        !_videoError &&
        !_cachingVideo) {
      _initVideo();
    }
  }

  Future<void> _initVideo() async {
    final url = widget.post.media.first.url;
    final fullUrl = _fullUrl(url);

    setState(() => _cachingVideo = true);

    try {
      final localPath = await FileCache.instance.downloadWithResume(
        fullUrl,
        onProgress: (v) {
          if (mounted) setState(() => _cacheProgress = v);
        },
        headers: authHeaders(),
      );

      if (!mounted) return;

      final file = File(localPath);

      if (await file.exists()) {
        final c = VideoPlayerController.file(file);
        _vc = c;

        await c.initialize();
        c.setLooping(true);

        AudioController.instance.muteTemporarily();

        if (mounted && widget.active) {
          c.play();
          _disc.repeat();
        }
      } else {
        final c = VideoPlayerController.networkUrl(Uri.parse(fullUrl));
        _vc = c;

        await c.initialize();
        c.setLooping(true);

        AudioController.instance.muteTemporarily();

        if (mounted && widget.active) {
          c.play();
          _disc.repeat();
        }
      }

      if (mounted) setState(() => _cachingVideo = false);
    } catch (_) {
      if (mounted) {
        setState(() {
          _videoError = true;
          _cachingVideo = false;
        });
      }
    }
  }

  @override
  void didUpdateWidget(covariant ReelItem old) {
    super.didUpdateWidget(old);

    final currentTab = context.read<AppState>().currentTab.value;
    final inReelsTab = currentTab == 2;

    if (!widget.active || !inReelsTab) {
      if (_vc != null) {
        _vc!.pause();
        _disc.stop();
        AudioController.instance.unmute();
      }
    } else if (widget.active && inReelsTab && _isVideo) {
      if (_vc == null && !_videoError && !_cachingVideo) {
        _initVideo();
      } else if (_vc != null && !_vc!.value.isPlaying && !_holding) {
        _vc!.play();
        _disc.repeat();
        AudioController.instance.muteTemporarily();
      }
    }
  }

  @override
  void dispose() {
    AudioController.instance.unmute();

    _vc?.dispose();
    _disc.dispose();
    _heartAnim.dispose();

    super.dispose();
  }

  void _toggleLike() {
    setState(() {
      widget.post.liked = !widget.post.liked;
      widget.post.likeCount += widget.post.liked ? 1 : -1;
    });

    ApiClient.instance
        .post('/api/posts/${widget.post.id}/like')
        .catchError((_) {});
  }

  void _toggleRetweet() {
    setState(() {
      widget.post.retweeted = !widget.post.retweeted;
      widget.post.retweetCount += widget.post.retweeted ? 1 : -1;
    });

    ApiClient.instance
        .post('/api/posts/${widget.post.id}/retweet')
        .catchError((_) {});
  }

  void _toggleBookmark() {
    setState(() => widget.post.bookmarked = !widget.post.bookmarked);

    ApiClient.instance
        .post('/api/posts/${widget.post.id}/bookmark')
        .catchError((_) {});
  }

  Future<void> _downloadReel() async {
    final m = widget.post.media.first;
    if (m.url.isEmpty) return;

    try {
      final status = await Permission.storage.request();

      if (!status.isGranted && Platform.isAndroid) {
        final s2 = await Permission.manageExternalStorage.request();

        if (!s2.isGranted) {
          if (mounted) showSnack(context, 'Storage permission required', error: true);
          return;
        }
      }
    } catch (_) {}

    final fullUrl = _fullUrl(m.url);

    try {
      showSnack(context, 'Downloading...');

      final path = await FileCache.instance.downloadWithResume(
        fullUrl,
        headers: authHeaders(),
      );

      if (mounted) {
        showSnack(context, 'Download complete ✓');
        OpenFile.open(path);
      }
    } catch (e) {
      if (mounted) showSnack(context, 'Download failed', error: true);
    }
  }

  void _onDoubleTap() {
    if (!widget.post.liked) {
      _toggleLike();
    }

    _heartAnim.forward(from: 0);
  }

  void _onLongPressStart(LongPressStartDetails details) {
    setState(() => _holding = true);

    if (_vc != null && _vc!.value.isPlaying) {
      _vc!.pause();
      _disc.stop();
    }
  }

  void _onLongPressEnd(LongPressEndDetails details) {
    setState(() => _holding = false);

    if (_vc != null && !_vc!.value.isPlaying) {
      _vc!.play();
      _disc.repeat();
    }
  }

  Future<void> _openAuthor() async {
    final author = widget.post.author;
    if (author == null) return;

    if (author.id != null && author.hasUnseenStory) {
      await Navigator.push(
        context,
        FadeRoute(StoryViewerScreen(userId: author.id!, user: author)),
      );

      if (mounted) {
        setState(() {
          widget.post.author = widget.post.author?.copyWithUnseenStory(false);
        });
      }
    } else {
      if (author.username.isNotEmpty) {
        Navigator.push(context, FadeRoute(ProfileScreen(username: author.username)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final m = post.media.first;
    final author = post.author;

    String? likedByText;

    if (post.likedByFollowings.isNotEmpty) {
      final names = post.likedByFollowings.take(2).map((e) => '@$e').toList();
      likedByText = 'Liked by ${names.join(', ')}';
    }

    return Container(
      color: Colors.black,
      child: Stack(fit: StackFit.expand, children: [
        GestureDetector(
          onDoubleTap: _onDoubleTap,
          onLongPressStart: _onLongPressStart,
          onLongPressEnd: _onLongPressEnd,
          onLongPressCancel: () => setState(() => _holding = false),
          child: Stack(fit: StackFit.expand, children: [
            if (_isVideo && !_videoError && _vc != null && _vc!.value.isInitialized)
              Center(
                child: AspectRatio(
                  aspectRatio: _vc!.value.aspectRatio,
                  child: VideoPlayer(_vc!),
                ),
              )
            else if (!_isVideo || _videoError)
              Positioned.fill(
                child: Container(
                  color: Colors.black,
                  child: CachedNetworkImage(
                    imageUrl: m.thumbnail ?? m.url,
                    fit: BoxFit.contain,
                    errorWidget: (_, __, ___) => Container(color: Colors.black12),
                  ),
                ),
              ),
            if (_heartAnim.isAnimating || _heartAnim.value > 0)
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _heartAnim,
                    builder: (_, __) {
                      final t = _heartAnim.value;

                      final scale = t < .3 ? t / .3 * 1.5 : 1.5 - (t - .3) * .28;
                      final opacity = t > .7 ? (1 - t) / .3 : 1.0;

                      return Opacity(
                        opacity: opacity.clamp(0.0, 1.0),
                        child: Center(
                          child: Transform.scale(
                            scale: scale,
                            child: const Icon(
                              Icons.favorite_rounded,
                              size: 120,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            if (_holding)
              Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.pause_rounded, color: Colors.white, size: 60),
                ),
              ),
            if (_cachingVideo)
              Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  SizedBox(
                    width: 50,
                    height: 50,
                    child: CircularProgressIndicator(
                      value: _cacheProgress > 0 ? _cacheProgress : null,
                      color: Colors.white,
                      strokeWidth: 3,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Loading video... ${(_cacheProgress * 100).toInt()}%',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ]),
              ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.black.withOpacity(.55), Colors.transparent],
                  begin: Alignment.topCenter,
                  end: Alignment.center,
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.transparent, Colors.black.withOpacity(.75)],
                  begin: Alignment.center,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            if (_isVideo &&
                _vc != null &&
                !_vc!.value.isPlaying &&
                !_holding &&
                !_cachingVideo)
              GestureDetector(
                onTap: () {
                  _vc!.play();
                  _disc.repeat();
                },
                child: Center(
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(.45),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 44,
                    ),
                  ),
                ),
              ),
          ]),
        ),
        Positioned(
          right: 10,
          bottom: 90,
          child: Column(children: [
            _railBtn(
              icon: post.liked
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              label: formatCount(post.likeCount),
              color: post.liked ? const Color(0xFFF91880) : Colors.white,
              onTap: _toggleLike,
            ),
            const SizedBox(height: 16),
            _railBtn(
              icon: Icons.chat_bubble_rounded,
              label: formatCount(post.replyCount),
              color: Colors.white,
              onTap: () => Navigator.push(
                context,
                FadeRoute(PostDetailScreen(postId: post.id, initial: post)),
              ),
            ),
            const SizedBox(height: 16),
            _railBtn(
              icon: Icons.repeat_rounded,
              label: formatCount(post.retweetCount),
              color: post.retweeted ? const Color(0xFF00BA7C) : Colors.white,
              onTap: _toggleRetweet,
            ),
            const SizedBox(height: 16),
            _railBtn(
              icon: post.bookmarked
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_border_rounded,
              label: 'Save',
              color: post.bookmarked ? const Color(0xFFFFD400) : Colors.white,
              onTap: _toggleBookmark,
            ),
            const SizedBox(height: 16),
            _railBtn(
              icon: Icons.download_rounded,
              label: 'Download',
              color: Colors.white,
              onTap: _downloadReel,
            ),
          ]),
        ),
        Positioned(
          left: 14,
          right: 80,
          bottom: 34,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            GestureDetector(
              onTap: _openAuthor,
              child: Row(children: [
                Avatar(
                  url: author?.avatarUrl,
                  size: 32,
                  ring: author?.hasUnseenStory ?? false,
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    '@${author?.username ?? 'user'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: Colors.white,
                    ),
                  ),
                ),
                if (author?.verified ?? false) ...[
                  const SizedBox(width: 4),
                  const Icon(Icons.verified_rounded, size: 15, color: Color(0xFF1D9BF0)),
                ],
                const SizedBox(width: 8),
                Text(
                  '· ${timeAgo(context, post.createdAt)}',
                  style: TextStyle(color: Colors.white.withOpacity(.7), fontSize: 12),
                ),
              ]),
            ),
            if (post.text.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  post.text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    height: 1.3,
                    color: Colors.white,
                  ),
                ),
              ),
            if (likedByText != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  likedByText,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            if (m.type == 'audio' && (m.title != null || m.artist != null))
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(children: [
                  const Icon(Icons.music_note_rounded, color: Colors.white, size: 14),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      '${m.title ?? 'Audio'}${m.artist != null ? ' • ${m.artist}' : ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.85),
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ]),
              ),
          ]),
        ),
        if (_isVideo && _vc != null && _vc!.value.isInitialized) ...[
          Positioned(
            top: 10,
            right: 14,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _muted = !_muted;
                  _vc!.setVolume(_muted ? 0 : 1);
                });
              },
              child: Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(.4),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: VideoProgressIndicator(
              _vc!,
              allowScrubbing: true,
              colors: VideoProgressColors(
                playedColor: const Color(0xFFF91880),
                bufferedColor: Colors.white24,
                backgroundColor: Colors.white10,
              ),
            ),
          ),
        ],
      ]),
    );
  }

  Widget _railBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Column(children: [
        Icon(icon, color: color, size: 30, shadows: [
          Shadow(color: Colors.black.withOpacity(.6), blurRadius: 8)
        ]),
        const SizedBox(height: 3),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            shadows: [Shadow(color: Colors.black.withOpacity(.6), blurRadius: 6)],
          ),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════ EXPLORE ══════════════════════════
class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final _api = ApiClient.instance;
  final _search = TextEditingController();

  Timer? _debounce;

  List<Post> _explore = [];
  List<User> _users = [];
  List<Post> _posts = [];
  List<Map<String, dynamic>> _tags = [];

  bool _loading = true;
  bool _searching = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _loadExplore();
  }

  Future<void> _loadExplore() async {
    try {
      final res = await _api.get('/api/explore');
      if (!mounted) return;

      if (res is Map) {
        final postsList = res['posts'];
        final usersList = res['users'];
        final tagsList = res['tags'];

        setState(() {
          _explore = (postsList is List ? postsList : [])
              .whereType<Map>()
              .map((e) => Post.fromJson(Map<String, dynamic>.from(e)))
              .toList();

          _users = (usersList is List ? usersList : [])
              .whereType<Map>()
              .map((e) => User.fromJson(Map<String, dynamic>.from(e)))
              .toList();

          _tags = (tagsList is List ? tagsList : [])
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();

          _loading = false;
        });
      } else {
        setState(() {
          _explore = extractItems(res).map(Post.fromJson).toList();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onQuery(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () => _doSearch(q));
  }

  Future<void> _doSearch(String q) async {
    setState(() {
      _query = q.trim();
      if (_query.isNotEmpty) _searching = true;
    });

    if (_query.isEmpty) {
      setState(() {
        _searching = false;
        _users = [];
        _posts = [];
      });
      return;
    }

    try {
      final res = await _api.get('/api/search', query: {'q': _query});
      if (!mounted) return;

      List<User> users = [];
      List<Post> posts = [];

      if (res is Map) {
        if (res['users'] is List) {
          users = (res['users'] as List)
              .whereType<Map>()
              .map((e) => User.fromJson(Map<String, dynamic>.from(e)))
              .toList();
        }

        if (res['posts'] is List) {
          posts = (res['posts'] as List)
              .whereType<Map>()
              .map((e) => Post.fromJson(Map<String, dynamic>.from(e)))
              .toList();
        }
      }

      setState(() {
        _users = users;
        _posts = posts;
        _searching = false;
      });
    } catch (_) {
      if (mounted) setState(() => _searching = false);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _applyBars(context);
    final p = _p(context);

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
        child: TextField(
          controller: _search,
          onChanged: _onQuery,
          style: TextStyle(fontSize: 14.5, color: p.text),
          decoration: InputDecoration(
            hintText: 'Search NokhodX…',
            hintStyle: TextStyle(color: p.sub),
            prefixIcon: Icon(Icons.search_rounded, color: p.sub),
            suffixIcon: _query.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.close_rounded, color: p.sub, size: 20),
                    onPressed: () {
                      _search.clear();
                      _doSearch('');
                    },
                  )
                : null,
            filled: true,
            fillColor: p.card,
            contentPadding: const EdgeInsets.symmetric(vertical: 13),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ),
      Expanded(
        child: _query.isEmpty
            ? _buildExplore()
            : _searching
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2.4))
                : _buildResults(),
      ),
    ]);
  }

  Widget _buildExplore() {
    final p = _p(context);

    if (_loading) {
      return GridView.count(
        crossAxisCount: 2,
        padding: const EdgeInsets.all(14),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: .82,
        physics: const NeverScrollableScrollPhysics(),
        children: List.generate(
          4,
          (_) => Shimmer.fromColors(
            baseColor: p.card,
            highlightColor: p.card2,
            child: Container(
              decoration: BoxDecoration(
                color: p.card,
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadExplore,
      color: p.accent,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 110),
        children: [
          if (_tags.isNotEmpty)
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: _tags.map((t) {
                  final tag = t['tag']?.toString() ?? '';
                  final count = jint(t['count']);

                  return GestureDetector(
                    onTap: () {
                      _search.text = '#$tag';
                      _doSearch('#$tag');
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: p.card,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: p.border),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(
                          '#$tag',
                          style: TextStyle(
                            color: p.accent,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          formatCount(count),
                          style: TextStyle(color: p.sub, fontSize: 11),
                        ),
                      ]),
                    ),
                  );
                }).toList(),
              ),
            ),
          if (_users.isNotEmpty) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 8),
              child: Text(
                'People',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: p.sub),
              ),
            ),
            SizedBox(
              height: 118,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                itemCount: _users.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, i) {
                  final u = _users[i];

                  return GestureDetector(
                    onTap: () => openUserOrStory(context, u),
                    child: Container(
                      width: 130,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: p.card,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: p.border),
                      ),
                      child: Column(children: [
                        Avatar(
                          url: u.avatarUrl,
                          size: 44,
                          ring: u.hasUnseenStory,
                        ),
                        const SizedBox(height: 6),
                        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Flexible(
                            child: Text(
                              u.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (u.verified) ...[
                            const SizedBox(width: 2),
                            Icon(Icons.verified_rounded, size: 13, color: p.accent),
                          ],
                        ]),
                        const SizedBox(height: 6),
                        FollowButton(user: u, compact: true),
                      ]),
                    ),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 10),
          if (_explore.isEmpty)
            const Padding(
              padding: EdgeInsets.all(40),
              child: EmptyState(
                icon: Icons.explore_outlined,
                title: 'Nothing to explore yet',
                subtitle: 'New posts will appear here.',
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: .82,
              ),
              itemCount: _explore.length,
              itemBuilder: (context, i) {
                final post = _explore[i];

                return SlideFadeIn(
                  delay: Duration(milliseconds: (i % 6) * 50),
                  child: GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      FadeRoute(PostDetailScreen(postId: post.id, initial: post)),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: p.card,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: p.border),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(fit: StackFit.expand, children: [
                        if (post.media.isNotEmpty)
                          CachedNetworkImage(
                            imageUrl:
                                post.media.first.thumbnail ?? post.media.first.url,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => Container(color: p.card2),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(gradient: p.brand),
                            child: Center(
                              child: Text(
                                post.text,
                                maxLines: 6,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13.5,
                                  height: 1.35,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        if (post.media.isNotEmpty &&
                            (post.media.first.type == 'video' ||
                                post.media.first.type == 'gif'))
                          const Center(
                            child: Icon(
                              Icons.play_circle_fill_rounded,
                              color: Colors.white70,
                              size: 44,
                            ),
                          ),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: GestureDetector(
                            onTap: () => openUserOrStory(context, post.author),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.transparent,
                                    Colors.black.withOpacity(.85)
                                  ],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                              ),
                              child: Row(children: [
                                Avatar(url: post.author?.avatarUrl, size: 22),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    '@${post.author?.username ?? 'user'}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                const Icon(
                                  Icons.favorite_rounded,
                                  size: 13,
                                  color: Color(0xFFF91880),
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  formatCount(post.likeCount),
                                  style: const TextStyle(fontSize: 11, color: Colors.white),
                                ),
                              ]),
                            ),
                          ),
                        ),
                      ]),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildResults() {
    final p = _p(context);

    if (_users.isEmpty && _posts.isEmpty) {
      return const EmptyState(
        icon: Icons.search_off_rounded,
        title: 'No results',
        subtitle: 'Nothing found',
      );
    }

    return ListView(padding: const EdgeInsets.only(bottom: 110), children: [
      if (_users.isNotEmpty) ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 8),
          child: Text(
            'People',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: p.sub),
          ),
        ),
        SizedBox(
          height: 118,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            itemCount: _users.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final u = _users[i];

              return GestureDetector(
                onTap: () => openUserOrStory(context, u),
                child: Container(
                  width: 130,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: p.card,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: p.border),
                  ),
                  child: Column(children: [
                    Avatar(
                      url: u.avatarUrl,
                      size: 44,
                      ring: u.hasUnseenStory,
                    ),
                    const SizedBox(height: 6),
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Flexible(
                        child: Text(
                          u.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (u.verified) ...[
                        const SizedBox(width: 2),
                        Icon(Icons.verified_rounded, size: 13, color: p.accent),
                      ],
                    ]),
                    const SizedBox(height: 6),
                    FollowButton(user: u, compact: true),
                  ]),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
      ],
      if (_posts.isNotEmpty) ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 4),
          child: Text(
            'Posts',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: p.sub),
          ),
        ),
        ..._posts.map((post) => Column(children: [
              PostCard(post: post),
              Divider(height: 1, thickness: 1, color: p.border.withOpacity(.4)),
            ])),
      ],
    ]);
  }
}

// ═══════════════════════════════ NOTIFICATIONS ═══════════════════
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _api = ApiClient.instance;

  List<Noti> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await _api.get('/api/notifications', query: {'limit': '50'});
      if (!mounted) return;

      setState(() {
        _items = extractItems(res).map(Noti.fromJson).toList();
        _loading = false;
      });
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Could not load.';
        });
      }
    }
  }

  Future<void> _markAllRead() async {
    try {
      await _api.post('/api/notifications/read');

      setState(() {
        for (final n in _items) {
          n.read = true;
        }
      });

      if (mounted) showSnack(context, 'All caught up ✅');
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    }
  }

  (IconData, Color) _iconFor(String type) {
    final p = _p(context);

    if (type.contains('like')) return (Icons.favorite_rounded, p.pink);
    if (type.contains('retweet') || type.contains('repost')) {
      return (Icons.repeat_rounded, p.green);
    }
    if (type.contains('follow')) return (Icons.person_add_rounded, p.accent);
    if (type.contains('reply')) return (Icons.chat_bubble_rounded, p.accent);
    if (type.contains('mention')) return (Icons.alternate_email_rounded, p.purple);
    if (type.contains('direct') || type.contains('message')) {
      return (Icons.mail_rounded, p.gold);
    }
    if (type.contains('quote')) return (Icons.format_quote_rounded, p.orange);
    if (type.contains('bookmark')) return (Icons.bookmark_rounded, p.gold);
    if (type.contains('group')) return (Icons.group_rounded, p.purple);

    return (Icons.notifications_rounded, p.sub);
  }

  String _verbFor(String type) {
    if (type.contains('like')) return 'liked your post';
    if (type.contains('retweet') || type.contains('repost')) {
      return 'reposted your post';
    }
    if (type.contains('follow')) return 'followed you';
    if (type.contains('reply')) return 'replied to your post';
    if (type.contains('mention')) return 'mentioned you';
    if (type.contains('bookmark')) return 'bookmarked your post';
    if (type.contains('quote')) return 'quoted your post';
    if (type.contains('direct')) return 'sent you a message';
    if (type.contains('group_add')) return 'added you to a group';

    return type.isEmpty ? 'interacted with you' : type;
  }

  @override
  Widget build(BuildContext context) {
    _applyBars(context);
    final p = _p(context);

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(18, 8, 8, 10),
        child: Row(children: [
          const Text(
            'Notifications',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 21),
          ),
          const Spacer(),
          IconButton(
            tooltip: 'Mark all as read',
            icon: Icon(Icons.done_all_rounded, color: p.sub),
            onPressed: _markAllRead,
          ),
        ]),
      ),
      Expanded(
        child: _loading
            ? ListView(
                children: List.generate(
                  6,
                  (_) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: ShimmerBlock(height: 66),
                  ),
                ),
              )
            : _error != null
                ? ErrorState(message: _error!, onRetry: _load)
                : _items.isEmpty
                    ? const EmptyState(
                        icon: Icons.notifications_none_rounded,
                        title: 'No notifications',
                        subtitle: "You're all caught up!",
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        color: p.accent,
                        backgroundColor: p.card2,
                        child: ListView.separated(
                          padding: const EdgeInsets.only(bottom: 110),
                          itemCount: _items.length,
                          separatorBuilder: (_, __) => Divider(
                            height: 1,
                            thickness: 1,
                            color: p.border.withOpacity(.35),
                          ),
                          itemBuilder: (context, i) {
                            final n = _items[i];
                            final (icon, color) = _iconFor(n.type);

                            return SlideFadeIn(
                              delay: Duration(milliseconds: (i % 10) * 35),
                              child: InkWell(
                                onTap: () {
                                  if (n.actor != null && n.type.contains('follow')) {
                                    openUserOrStory(context, n.actor);
                                  } else if (n.postId != null && n.postId! > 0) {
                                    Navigator.push(
                                      context,
                                      FadeRoute(PostDetailScreen(postId: n.postId)),
                                    );
                                  }
                                },
                                child: Container(
                                  color: n.read
                                      ? Colors.transparent
                                      : p.accent.withOpacity(.05),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 13,
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      GestureDetector(
                                        onTap: n.actor != null
                                            ? () => openUserOrStory(context, n.actor)
                                            : null,
                                        child: Container(
                                          width: 42,
                                          height: 42,
                                          decoration: BoxDecoration(
                                            color: color.withOpacity(.15),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(icon, color: color, size: 21),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            GestureDetector(
                                              onTap: n.actor != null
                                                  ? () => openUserOrStory(
                                                        context,
                                                        n.actor,
                                                      )
                                                  : null,
                                              child: Text.rich(
                                                TextSpan(
                                                  style: const TextStyle(fontSize: 13.8),
                                                  children: [
                                                    if (n.actor != null)
                                                      TextSpan(
                                                        text: n.actor!.displayName,
                                                        style: const TextStyle(
                                                          fontWeight: FontWeight.w800,
                                                        ),
                                                      ),
                                                    TextSpan(
                                                      text:
                                                          ' ${n.text ?? _verbFor(n.type)}',
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              timeAgo(context, n.createdAt),
                                              style: TextStyle(color: p.sub, fontSize: 12),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (!n.read)
                                        Container(
                                          margin: const EdgeInsets.only(top: 6),
                                          width: 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            color: p.accent,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
      ),
    ]);
  }
}

// ═══════════════════════════════ MESSAGES ═════════════════════════
class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final _api = ApiClient.instance;

  List<Conversation> _convs = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await _api.get('/api/dm/conversations');
      if (!mounted) return;

      setState(() {
        _convs = extractItems(res).map(Conversation.fromJson).toList();
        _loading = false;
      });
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Could not load.';
        });
      }
    }
  }

  User? _other(Conversation c) {
    final me = context.read<AppState>().me;

    for (final m in c.members) {
      if (me == null) return m;
      if (m.username != me.username && m.id != me.id) return m;
    }

    return c.members.isNotEmpty ? c.members.first : null;
  }

  String _title(Conversation c) {
    if (c.name != null && c.name!.isNotEmpty) return c.name!;
    if (c.isGroup) return 'Group chat';
    return _other(c)?.displayName ?? 'Conversation';
  }

  @override
  Widget build(BuildContext context) {
    _applyBars(context);
    final p = _p(context);

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 10),
        child: Row(children: [
          const Text(
            'Messages',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 21),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              SlideUpRoute(const NewConversationScreen()),
            ).then((_) => _load()),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(gradient: p.brand, shape: BoxShape.circle),
              child: const Icon(Icons.edit_rounded, color: Colors.white, size: 18),
            ),
          ),
        ]),
      ),
      Expanded(
        child: _loading
            ? ListView(
                children: List.generate(
                  6,
                  (_) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: ShimmerBlock(height: 64),
                  ),
                ),
              )
            : _error != null
                ? ErrorState(message: _error!, onRetry: _load)
                : _convs.isEmpty
                    ? const EmptyState(
                        icon: Icons.chat_bubble_outline_rounded,
                        title: 'No conversations',
                        subtitle: 'Start chatting with your friends!',
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        color: p.accent,
                        backgroundColor: p.card2,
                        child: ListView.builder(
                          padding: const EdgeInsets.only(bottom: 110),
                          itemCount: _convs.length,
                          itemBuilder: (context, i) {
                            final c = _convs[i];
                            final other = _other(c);
                            final isOnlineOther = other?.isOnline ?? false;

                            final lastMsg = c.lastMessage;

                            final lastText = lastMsg?.deleted == true
                                ? 'Message deleted'
                                : (lastMsg?.text.isNotEmpty == true
                                    ? lastMsg!.text
                                    : (lastMsg?.media.isNotEmpty == true
                                        ? '📎 Media'
                                        : 'Say hi 👋'));

                            final lastTime = lastMsg?.createdAt;

                            return SlideFadeIn(
                              delay: Duration(milliseconds: (i % 10) * 40),
                              child: InkWell(
                                onTap: () => Navigator.push(
                                  context,
                                  FadeRoute(ChatScreen(conversation: c)),
                                ).then((_) => _load()),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 10,
                                  ),
                                  child: Row(children: [
                                    GestureDetector(
                                      onTap: () => openUserOrStory(context, other),
                                      child: Stack(children: [
                                        Avatar(
                                          url: other?.avatarUrl,
                                          size: 52,
                                          ring: other?.hasUnseenStory ?? false,
                                          fallback: _title(c),
                                        ),
                                        if (c.isGroup)
                                          Positioned(
                                            right: 0,
                                            bottom: 0,
                                            child: Container(
                                              padding: const EdgeInsets.all(3),
                                              decoration: BoxDecoration(
                                                color: p.purple,
                                                shape: BoxShape.circle,
                                                border: Border.all(color: p.bg, width: 2),
                                              ),
                                              child: const Icon(
                                                Icons.group_rounded,
                                                size: 11,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        if (!c.isGroup && isOnlineOther)
                                          Positioned(
                                            right: 2,
                                            bottom: 2,
                                            child: Container(
                                              width: 12,
                                              height: 12,
                                              decoration: BoxDecoration(
                                                color: p.green,
                                                shape: BoxShape.circle,
                                                border: Border.all(color: p.bg, width: 2),
                                              ),
                                            ),
                                          ),
                                      ]),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(children: [
                                            Flexible(
                                              child: Text(
                                                _title(c),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontWeight: c.unread > 0
                                                      ? FontWeight.w900
                                                      : FontWeight.w700,
                                                  fontSize: 14.5,
                                                  color: p.text,
                                                ),
                                              ),
                                            ),
                                            const Spacer(),
                                            if (lastTime != null)
                                              Text(
                                                timeAgo(context, lastTime),
                                                style: TextStyle(
                                                  fontSize: 11.5,
                                                  color: c.unread > 0 ? p.accent : p.sub,
                                                ),
                                              ),
                                          ]),
                                          const SizedBox(height: 3),
                                          Row(children: [
                                            Expanded(
                                              child: Text(
                                                lastText,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: c.unread > 0 ? p.text : p.sub,
                                                  fontWeight: c.unread > 0
                                                      ? FontWeight.w600
                                                      : FontWeight.w400,
                                                ),
                                              ),
                                            ),
                                            if (c.unread > 0)
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 7,
                                                  vertical: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  gradient: p.brand,
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                                child: Text(
                                                  '${c.unread}',
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w800,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                          ]),
                                        ],
                                      ),
                                    ),
                                  ]),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
      ),
    ]);
  }
}

class NewConversationScreen extends StatefulWidget {
  const NewConversationScreen({super.key});

  @override
  State<NewConversationScreen> createState() => _NewConversationScreenState();
}

class _NewConversationScreenState extends State<NewConversationScreen> {
  final _api = ApiClient.instance;

  final _search = TextEditingController();
  final _groupName = TextEditingController();

  List<User> _users = [];
  final Set<int> _selected = {};

  bool _loading = false;
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    _doSearch('');
  }

  Future<void> _doSearch(String q) async {
    setState(() => _loading = true);

    try {
      final res = await _api.get('/api/users', query: {
        if (q.isNotEmpty) 'q': q,
        'limit': '50'
      });

      if (!mounted) return;

      final me = context.read<AppState>().me;

      setState(() {
        _users = extractItems(res)
            .map(User.fromJson)
            .where((u) => u.username != me?.username)
            .toList();

        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _create() async {
    if (_selected.isEmpty || _creating) return;

    setState(() => _creating = true);

    try {
      final isGroup = _selected.length > 1;

      final res = await _api.post('/api/dm/conversations', body: {
        'user_ids': _selected.toList(),
        if (isGroup && _groupName.text.trim().isNotEmpty)
          'name': _groupName.text.trim(),
        'is_group': isGroup,
      });

      Conversation? conv;

      if (res is Map) {
        try {
          conv = Conversation.fromJson(Map<String, dynamic>.from(res));
        } catch (_) {}
      }

      if (!mounted) return;

      if (conv?.id != null) {
        Navigator.pushReplacement(
          context,
          FadeRoute(ChatScreen(conversation: conv!)),
        );
      } else {
        Navigator.pop(context);
      }
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  void dispose() {
    _search.dispose();
    _groupName.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = _p(context);

    return Scaffold(
      backgroundColor: p.bg,
      appBar: AppBar(
        title: const Text(
          'New message',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GradientButton(
              text: 'Create',
              width: 100,
              height: 40,
              loading: _creating,
              onPressed: _selected.isNotEmpty ? _create : null,
            ),
          ),
        ],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(14),
          child: TextField(
            controller: _search,
            onChanged: (q) => _doSearch(q.trim()),
            style: TextStyle(color: p.text),
            decoration: InputDecoration(
              hintText: 'Search people…',
              hintStyle: TextStyle(color: p.sub),
              prefixIcon: Icon(Icons.search_rounded, color: p.sub),
              filled: true,
              fillColor: p.card,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(22),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        if (_selected.length > 1)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
            child: TextField(
              controller: _groupName,
              decoration: InputDecoration(
                hintText: 'Group name (optional)',
                hintStyle: TextStyle(color: p.sub),
                filled: true,
                fillColor: p.card,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 16,
                ),
              ),
            ),
          ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(strokeWidth: 2.4))
              : ListView.builder(
                  itemCount: _users.length,
                  itemBuilder: (context, i) {
                    final u = _users[i];
                    final selected = u.id != null && _selected.contains(u.id);

                    return ListTile(
                      onTap: u.id == null
                          ? null
                          : () => setState(() {
                                if (selected) {
                                  _selected.remove(u.id);
                                } else {
                                  _selected.add(u.id!);
                                }
                              }),
                      leading: Stack(children: [
                        Avatar(url: u.avatarUrl, size: 46),
                        if (selected)
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                gradient: p.brand,
                                shape: BoxShape.circle,
                                border: Border.all(color: p.bg, width: 2),
                              ),
                              child: const Icon(
                                Icons.check_rounded,
                                size: 11,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ]),
                      title: Row(children: [
                        Flexible(
                          child: Text(
                            u.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        if (u.verified) ...[
                          const SizedBox(width: 4),
                          Icon(Icons.verified_rounded, size: 15, color: p.accent),
                        ],
                      ]),
                      subtitle: Text(
                        '@${u.username}',
                        style: TextStyle(color: p.sub, fontSize: 12.5),
                      ),
                      trailing: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: selected ? p.accent : Colors.transparent,
                          border: Border.all(
                            color: selected ? p.accent : p.sub,
                            width: 1.6,
                          ),
                        ),
                        child: selected
                            ? const Icon(Icons.check_rounded, size: 15, color: Colors.white)
                            : null,
                      ),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}

class ChatScreen extends StatefulWidget {
  final Conversation conversation;

  const ChatScreen({super.key, required this.conversation});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _api = ApiClient.instance;

  final _input = TextEditingController();
  final _scroll = ScrollController();

  List<DM> _messages = [];

  bool _loading = true;
  bool _sending = false;
  bool _loadingOlder = false;
  bool _hasMore = true;

  bool _attaching = false;
  double _attachProgress = 0;
  String? _attachName;

  DM? _replyTo;

  int? _dragId;
  double _dragDx = 0;
  bool _dragVibrated = false;

  int? get _convId => widget.conversation.id;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _load();
  }

  void _onScroll() {
    if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 250 &&
        !_loadingOlder &&
        _hasMore &&
        !_loading) {
      _loadOlder();
    }
  }

  Future<void> _load() async {
    if (_convId == null) {
      setState(() => _loading = false);
      return;
    }

    try {
      final res = await _api.get(
        '/api/dm/conversations/$_convId/messages',
        query: {'limit': '50'},
      );

      if (!mounted) return;

      final items = extractItems(res).map(DM.fromJson).toList();

      setState(() {
        _messages = items.reversed.toList();
        _hasMore = items.length >= 50;
        _loading = false;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) _scroll.jumpTo(0);
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadOlder() async {
    if (_messages.isEmpty) return;

    setState(() => _loadingOlder = true);

    try {
      final oldest = _messages.last.id;

      final res = await _api.get(
        '/api/dm/conversations/$_convId/messages',
        query: {
          'limit': '50',
          if (oldest != null) 'before_id': '$oldest'
        },
      );

      final older = extractItems(res).map(DM.fromJson).toList().reversed.toList();
      if (!mounted) return;

      setState(() {
        _messages.addAll(older);
        _hasMore = older.length >= 50;
        _loadingOlder = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingOlder = false);
    }
  }

  Future<void> _send({String? overrideText}) async {
    final text = (overrideText ?? _input.text).trim();

    if (text.isEmpty || _sending || _convId == null) return;

    setState(() => _sending = true);

    try {
      final res = await _api.post('/api/dm/conversations/$_convId/messages', body: {
        'text': text,
        if (_replyTo?.id != null) 'reply_to_id': _replyTo!.id,
      });

      _input.clear();

      final replyTo = _replyTo;
      setState(() => _replyTo = null);

      DM? sent;

      if (res is Map) {
        try {
          sent = DM.fromJson(Map<String, dynamic>.from(res));
        } catch (_) {}
      }

      setState(() {
        if (sent != null && sent.id != null) {
          _messages.insert(0, sent);
        } else {
          final me = context.read<AppState>().me;

          _messages.insert(
            0,
            DM(
              text: text,
              senderId: me?.id,
              sender: me,
              replyToId: replyTo?.id,
              replyParent: replyTo,
              createdAt: DateTime.now().toUtc().toIso8601String(),
            ),
          );
        }
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.animateTo(
            0,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        }
      });
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _attachMenu() {
    final p = _p(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: p.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            margin: const EdgeInsets.only(top: 10),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: p.border,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          ListTile(
            leading: Icon(Icons.image_rounded, color: p.accent),
            title: const Text('Image', style: TextStyle(fontWeight: FontWeight.w600)),
            onTap: () {
              Navigator.pop(ctx);
              _pickAndSend('image');
            },
          ),
          ListTile(
            leading: Icon(Icons.videocam_rounded, color: p.pink),
            title: const Text('Video', style: TextStyle(fontWeight: FontWeight.w600)),
            onTap: () {
              Navigator.pop(ctx);
              _pickAndSend('video');
            },
          ),
          ListTile(
            leading: Icon(Icons.audiotrack_rounded, color: p.purple),
            title: const Text('Audio', style: TextStyle(fontWeight: FontWeight.w600)),
            onTap: () {
              Navigator.pop(ctx);
              _pickAndSend('audio');
            },
          ),
          ListTile(
            leading: Icon(Icons.attach_file_rounded, color: p.gold),
            title: const Text('Any file', style: TextStyle(fontWeight: FontWeight.w600)),
            onTap: () {
              Navigator.pop(ctx);
              _pickAndSend('file');
            },
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  Future<void> _pickAndSend(String type) async {
    String? path;
    String? name;

    try {
      if (type == 'image') {
        final f = await ImagePicker().pickImage(
          source: ImageSource.gallery,
          imageQuality: 85,
        );

        path = f?.path;
        name = f?.name;
      } else if (type == 'video') {
        final f = await ImagePicker().pickVideo(
          source: ImageSource.gallery,
          maxDuration: const Duration(minutes: 5),
        );

        path = f?.path;
        name = f?.name;
      } else if (type == 'audio') {
        final result = await FilePicker.platform.pickFiles(type: FileType.audio);

        if (result != null && result.files.isNotEmpty) {
          path = result.files.first.path;
          name = result.files.first.name;
        }
      } else {
        final result = await FilePicker.platform.pickFiles(type: FileType.any);

        if (result != null && result.files.isNotEmpty) {
          path = result.files.first.path;
          name = result.files.first.name;
        }
      }
    } catch (_) {}

    if (path == null) return;

    await _uploadAndSend(path, name);
  }

  Future<void> _uploadAndSend(String path, String? name) async {
    if (_convId == null || _attaching) return;

    setState(() {
      _attaching = true;
      _attachProgress = 0;
      _attachName = name ?? path.split('/').last;
    });

    try {
      final res = await _api.uploadMedia(
        path,
        onProgress: (v) {
          if (mounted) setState(() => _attachProgress = v);
        },
      );

      String id = '';

      if (res is Map) {
        id = jstr(jpick(res, ['id', 'media_id']));

        if (id.isEmpty) {
          final u = resolveMedia(res);
          if (u != null) id = u;
        }
      }

      if (id.isEmpty) throw ApiException('Upload failed');

      await _api.post('/api/dm/conversations/$_convId/messages', body: {
        'text': _input.text.trim().isEmpty ? ' ' : _input.text.trim(),
        'media_ids': [id],
      });

      _input.clear();
      await _load();

      if (mounted) showSnack(context, 'Attachment sent');
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } catch (_) {
      if (mounted) showSnack(context, 'Attachment failed', error: true);
    } finally {
      if (mounted) {
        setState(() {
          _attaching = false;
          _attachProgress = 0;
          _attachName = null;
        });
      }
    }
  }

  Widget _swipeable(DM m, bool mine, Widget child) {
    if (m.id == null) return child;

    final dx = _dragId == m.id ? _dragDx : 0.0;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragStart: (_) {
        setState(() {
          _dragId = m.id;
          _dragDx = 0;
          _dragVibrated = false;
        });
      },
      onHorizontalDragUpdate: (d) {
        double next = _dragDx + d.delta.dx;

        if (mine) {
          next = next.clamp(-120.0, 0.0);
        } else {
          next = next.clamp(0.0, 120.0);
        }

        if (!_dragVibrated && next.abs() > 70) {
          _dragVibrated = true;
          HapticFeedback.selectionClick();

          setState(() => _replyTo = m);
        }

        setState(() => _dragDx = next);
      },
      onHorizontalDragEnd: (_) {
        setState(() {
          _dragId = null;
          _dragDx = 0;
        });
      },
      onHorizontalDragCancel: () {
        setState(() {
          _dragId = null;
          _dragDx = 0;
        });
      },
      child: Transform.translate(
        offset: Offset(dx, 0),
        child: child,
      ),
    );
  }

  void _messageMenu(DM m) {
    final p = _p(context);
    final me = context.read<AppState>().me;

    final mine = m.senderId == me?.id || m.sender?.username == me?.username;

    showModalBottomSheet(
      context: context,
      backgroundColor: p.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            margin: const EdgeInsets.only(top: 10),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: p.border,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          ListTile(
            leading: Icon(Icons.reply_rounded, color: p.accent),
            title: const Text('Reply', style: TextStyle(fontWeight: FontWeight.w600)),
            onTap: () {
              Navigator.pop(ctx);
              setState(() => _replyTo = m);
            },
          ),
          if (mine)
            ListTile(
              leading: Icon(Icons.edit_outlined, color: p.gold),
              title: const Text('Edit', style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(ctx);
                _editMessage(m);
              },
            ),
          if (mine)
            ListTile(
              leading: Icon(Icons.delete_outline_rounded, color: p.red),
              title: Text(
                'Delete',
                style: TextStyle(color: p.red, fontWeight: FontWeight.w600),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _deleteMessage(m);
              },
            ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  Future<void> _editMessage(DM m) async {
    final p = _p(context);

    final c = TextEditingController(text: m.text);

    final newText = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: p.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text(
          'Edit message',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        content: TextField(
          controller: c,
          autofocus: true,
          style: TextStyle(color: p.text),
          decoration: InputDecoration(
            filled: true,
            fillColor: p.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: p.sub)),
          ),
          GradientButton(
            text: 'Save',
            width: 90,
            height: 38,
            onPressed: () => Navigator.pop(ctx, c.text),
          ),
        ],
      ),
    );

    if (newText == null || newText.trim().isEmpty || m.id == null) return;

    try {
      await _api.put('/api/dm/messages/${m.id}', body: {'text': newText.trim()});
      setState(() => _load());
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    }
  }

  Future<void> _deleteMessage(DM m) async {
    if (m.id == null) return;

    try {
      await _api.delete('/api/dm/messages/${m.id}');
      setState(() => _messages.removeWhere((x) => x.id == m.id));

      if (mounted) showSnack(context, 'Message deleted');
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    }
  }

  String _title() {
    final c = widget.conversation;

    if (c.name != null && c.name!.isNotEmpty) return c.name!;

    final me = context.read<AppState>().me;

    for (final m in c.members) {
      if (m.username != me?.username) return m.displayName;
    }

    return c.members.isNotEmpty ? c.members.first.displayName : 'Chat';
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _applyBars(context);

    final p = _p(context);
    final me = context.watch<AppState>().me;
    final conv = widget.conversation;

    final other = conv.members.firstWhere(
      (m) => m.username != me?.username,
      orElse: () => conv.members.isNotEmpty
          ? conv.members.first
          : User(username: ''),
    );

    final isOnlineOther = other.isOnline;

    return Scaffold(
      backgroundColor: p.bg,
      appBar: AppBar(
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: GestureDetector(
          onTap: () => openUserOrStory(context, other),
          child: Row(children: [
            Stack(children: [
              Avatar(
                url: other.avatarUrl,
                size: 36,
                ring: other.hasUnseenStory,
                fallback: _title(),
              ),
              if (!conv.isGroup && isOnlineOther)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: p.green,
                      shape: BoxShape.circle,
                      border: Border.all(color: p.bg, width: 2),
                    ),
                  ),
                ),
            ]),
            const SizedBox(width: 10),
            Flexible(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  _title(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15.5,
                    color: p.text,
                  ),
                ),
                Text(
                  conv.isGroup
                      ? '${conv.members.length} members'
                      : (isOnlineOther
                          ? 'Online'
                          : 'Last seen ${timeAgo(context, other.lastSeen)}'),
                  style: TextStyle(
                    fontSize: 11,
                    color: isOnlineOther ? p.green : p.sub,
                  ),
                ),
              ]),
            ),
          ]),
        ),
      ),
      body: Column(children: [
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(strokeWidth: 2.4))
              : _messages.isEmpty
                  ? const EmptyState(
                      icon: Icons.waving_hand_rounded,
                      title: 'No messages yet',
                      subtitle: 'Say hello!',
                    )
                  : ListView.builder(
                      controller: _scroll,
                      reverse: true,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      itemCount: _messages.length + (_loadingOlder ? 1 : 0),
                      itemBuilder: (context, i) {
                        if (i == _messages.length) {
                          return const Padding(
                            padding: EdgeInsets.all(14),
                            child: Center(
                              child: CircularProgressIndicator(strokeWidth: 2.2),
                            ),
                          );
                        }

                        final m = _messages[i];
                        final mine =
                            m.senderId == me?.id || m.sender?.username == me?.username;

                        final bubble = GestureDetector(
                          onLongPress: () => _messageMenu(m),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              gradient: mine ? p.brand : null,
                              color: mine ? null : p.card,
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(18),
                                topRight: const Radius.circular(18),
                                bottomLeft: Radius.circular(mine ? 18 : 4),
                                bottomRight: Radius.circular(mine ? 4 : 18),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (!mine && conv.isGroup && m.sender != null)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 3),
                                    child: GestureDetector(
                                      onTap: () => openUserOrStory(context, m.sender),
                                      child: Text(
                                        m.sender?.displayName ?? m.sender!.username,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color: hashColor(m.sender!.username),
                                        ),
                                      ),
                                    ),
                                  ),
                                if (m.replyToId != null &&
                                    m.replyParent != null &&
                                    m.replyParent!.text.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                                    margin: const EdgeInsets.only(bottom: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.white
                                          .withOpacity(mine ? .15 : .08),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border(
                                        left: BorderSide(
                                          color: mine ? Colors.white : p.accent,
                                          width: 3,
                                        ),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '↩ Reply',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: mine
                                                ? Colors.white.withOpacity(.7)
                                                : p.accent,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        Text(
                                          m.replyParent!.text,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: mine
                                                ? Colors.white.withOpacity(.85)
                                                : p.text,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                if (m.media.isNotEmpty)
                                  for (final mm in m.media)
                                    if (mm.type == 'file')
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 6),
                                        child: FileCard(media: mm),
                                      )
                                    else if (mm.type == 'audio')
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 6),
                                        child: AudioChip(media: mm),
                                      )
                                    else
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 6),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(12),
                                          child: GestureDetector(
                                            onTap: () {
                                              if (mm.type == 'video' ||
                                                  mm.type == 'gif') {
                                                Navigator.push(
                                                  context,
                                                  FadeRoute(FullScreenVideoScreen(
                                                    url: mm.url,
                                                    thumbnail: mm.thumbnail,
                                                  )),
                                                );
                                              } else {
                                                Navigator.push(
                                                  context,
                                                  FadeRoute(MediaViewerScreen(
                                                    media: mm,
                                                    heroTag: 'dm_${m.id}_${mm.id}',
                                                  )),
                                                );
                                              }
                                            },
                                            child: Stack(children: [
                                              CachedNetworkImage(
                                                imageUrl: mm.thumbnail ?? mm.url,
                                                fit: BoxFit.cover,
                                                width: 200,
                                                height: 150,
                                                errorWidget: (_, __, ___) => Container(
                                                  width: 200,
                                                  height: 150,
                                                  color: p.card2,
                                                ),
                                              ),
                                              if (mm.type == 'video' ||
                                                  mm.type == 'gif')
                                                Positioned.fill(
                                                  child: Container(
                                                    color:
                                                        Colors.black.withOpacity(.25),
                                                    child: const Center(
                                                      child: Icon(
                                                        Icons
                                                            .play_circle_fill_rounded,
                                                        color: Colors.white70,
                                                        size: 44,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                            ]),
                                          ),
                                        ),
                                      ),
                                if (m.deleted)
                                  Text(
                                    'This message was deleted',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontStyle: FontStyle.italic,
                                      color: mine
                                          ? Colors.white.withOpacity(.7)
                                          : p.sub,
                                    ),
                                  )
                                else if (m.text.trim().isNotEmpty)
                                  Padding(
                                    padding: EdgeInsets.only(
                                      top: m.media.isNotEmpty ? 6 : 0,
                                    ),
                                    child: Text(
                                      m.text,
                                      style: TextStyle(
                                        fontSize: 14,
                                        height: 1.3,
                                        color: mine ? Colors.white : p.text,
                                      ),
                                    ),
                                  ),
                                Padding(
                                  padding: const EdgeInsets.only(top: 3),
                                  child: Text(
                                    timeAgo(context, m.createdAt),
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      color: mine
                                          ? Colors.white.withOpacity(.7)
                                          : p.sub,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            mainAxisAlignment:
                                mine ? MainAxisAlignment.end : MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (!mine) ...[
                                GestureDetector(
                                  onTap: () => openUserOrStory(context, m.sender),
                                  child: Avatar(
                                    url: m.sender?.avatarUrl,
                                    size: 28,
                                    ring: m.sender?.hasUnseenStory ?? false,
                                  ),
                                ),
                                const SizedBox(width: 6),
                              ],
                              Flexible(
                                child: _swipeable(m, mine, bubble),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
        ),
        if (_attaching)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: p.surface,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.upload_file_rounded, size: 16, color: p.accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Uploading ${_attachName ?? 'file'}…',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: p.sub),
                  ),
                ),
                Text(
                  '${(_attachProgress * 100).toInt()}%',
                  style: TextStyle(fontSize: 12, color: p.accent),
                ),
              ]),
              const SizedBox(height: 6),
              LinearProgressIndicator(
                value: _attachProgress,
                color: p.accent,
                backgroundColor: p.card2,
              ),
            ]),
          ),
        if (_replyTo != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: p.surface,
            child: Row(children: [
              Icon(Icons.reply_rounded, size: 18, color: p.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Replying to: ${_replyTo!.text}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12.5, color: p.sub),
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _replyTo = null),
                child: Icon(Icons.close_rounded, size: 17, color: p.sub),
              ),
            ]),
          ),
        SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 10, 8),
            decoration: BoxDecoration(
              color: p.surface,
              border: Border(top: BorderSide(color: p.border)),
            ),
            child: Row(children: [
              IconButton(
                icon: Icon(Icons.add_circle_rounded, color: p.accent),
                onPressed: _attaching ? null : _attachMenu,
              ),
              Expanded(
                child: TextField(
                  controller: _input,
                  maxLines: 4,
                  minLines: 1,
                  style: TextStyle(fontSize: 14.5, color: p.text),
                  onSubmitted: (_) => _send(),
                  decoration: InputDecoration(
                    hintText: 'Message…',
                    hintStyle: TextStyle(color: p.sub),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 11,
                    ),
                    filled: true,
                    fillColor: p.card,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _sending || _attaching ? null : () => _send(),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    gradient: p.brand,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: p.accent.withOpacity(.4), blurRadius: 14)
                    ],
                  ),
                  child: _sending
                      ? const Padding(
                          padding: EdgeInsets.all(13),
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send_rounded, color: Colors.white, size: 21),
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════ PROFILE ═════════════════════════
class ProfileScreen extends StatefulWidget {
  final String username;

  const ProfileScreen({super.key, required this.username});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _api = ApiClient.instance;

  User? _user;
  bool _loading = true;
  String? _error;
  bool _following = false;
  int _activeTab = 0;

  final Map<String, List<Post>> _tabCache = {};
  final Map<String, bool> _tabLoading = {};

  bool get _isMe => context.read<AppState>().me?.username == widget.username;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await _api.get('/api/users/${widget.username}');
      if (!mounted) return;

      setState(() {
        _user = User.fromJson(Map<String, dynamic>.from(res is Map ? res : {}));
        _following = _user?.isFollowing ?? false;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Profile not found.';
        });
      }
    }
  }

  Future<List<Post>> _tabPosts(String kind) async {
    if (_tabCache.containsKey(kind)) return _tabCache[kind]!;

    _tabLoading[kind] = true;

    try {
      final path = kind == 'posts'
          ? '/api/users/${widget.username}/posts'
          : '/api/users/${widget.username}/media';

      final res = await _api.get(path, query: {'limit': '40'});

      var items = extractItems(res).map(Post.fromJson).toList();

      if (kind == 'media') {
        items = items.where((x) => x.media.isNotEmpty).toList();
      }

      _tabCache[kind] = items;
      return items;
    } catch (_) {
      _tabCache[kind] = [];
      return [];
    } finally {
      _tabLoading[kind] = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> _toggleFollow() async {
    if (_user == null) return;

    setState(() {
      _following = !_following;

      _user = User(
        id: _user!.id,
        username: _user!.username,
        name: _user!.name,
        bio: _user!.bio,
        email: _user!.email,
        avatarItems: _user!.avatarItems,
        musicItems: _user!.musicItems,
        verified: _user!.verified,
        isAdmin: _user!.isAdmin,
        isFollowing: _following,
        isOnline: _user!.isOnline,
        followers: _user!.followers + (_following ? 1 : -1),
        following: _user!.following,
        posts: _user!.posts,
        lastSeen: _user!.lastSeen,
        hasUnseenStory: _user!.hasUnseenStory,
        followedByFollowings: _user!.followedByFollowings,
      );
    });

    try {
      await _api.post('/api/users/${widget.username}/follow');
    } catch (e) {
      if (mounted) {
        setState(() => _following = !_following);
        showSnack(context, e.toString(), error: true);
      }
    }
  }

  void _profileMenu() {
    final p = _p(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: p.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            margin: const EdgeInsets.only(top: 10),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: p.border,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          ListTile(
            leading: Icon(Icons.copy_rounded, color: p.text),
            title: const Text(
              'Copy username',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            onTap: () {
              Navigator.pop(ctx);
              Clipboard.setData(ClipboardData(text: '@${widget.username}'));
              showSnack(context, 'Copied');
            },
          ),
          if (_isMe || context.read<AppState>().me?.isAdmin == true)
            ListTile(
              leading: Icon(Icons.verified_rounded, color: p.gold),
              title: const Text(
                'Verify user (Admin)',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              onTap: () async {
                Navigator.pop(ctx);

                try {
                  await _api.post(
                    '/api/admin/users/${widget.username}/verify',
                    body: {'verified': true},
                  );

                  if (mounted) showSnack(context, 'User verified ✅');

                  _load();
                } on ApiException catch (e) {
                  if (mounted) showSnack(context, e.message, error: true);
                }
              },
            ),
          if (_isMe)
            ListTile(
              leading: Icon(Icons.settings_outlined, color: p.text),
              title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(ctx);
                openSettings(context);
              },
            ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  void _openMusicSheet() {
    if (_user == null || _user!.musicItems.isEmpty) return;

    final p = _p(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: p.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, controller) {
          return Container(
            decoration: BoxDecoration(
              color: p.card,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(children: [
              Container(
                margin: const EdgeInsets.only(top: 10),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: p.border,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(gradient: p.brand, shape: BoxShape.circle),
                    child: const Icon(Icons.music_note_rounded, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Profile Music',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
                  ),
                ]),
              ),
              Expanded(
                child: ListView.builder(
                  controller: controller,
                  padding: const EdgeInsets.all(12),
                  itemCount: _user!.musicItems.length,
                  itemBuilder: (ctx, i) {
                    final m = _user!.musicItems[i];
                    return _MusicSheetItem(media: m);
                  },
                ),
              ),
            ]),
          );
        },
      ),
    );
  }

  Widget _buildTabContent() {
    final kind = _activeTab == 0 ? 'posts' : 'media';
    final isGrid = _activeTab == 1;

    return _ProfileTab(
      loader: () => _tabPosts(kind),
      loading: _tabLoading[kind] ?? false,
      grid: isGrid,
    );
  }

  Widget _stat(int n, String label) {
    final p = _p(context);

    return Column(children: [
      Text(
        formatCount(n),
        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: p.text),
      ),
      const SizedBox(height: 2),
      Text(label, style: TextStyle(color: p.sub, fontSize: 12)),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    _applyBars(context);
    final p = _p(context);

    if (_loading) {
      return Scaffold(
        backgroundColor: p.bg,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null || _user == null) {
      return Scaffold(
        backgroundColor: p.bg,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: ErrorState(message: _error ?? 'Not found', onRetry: _load),
      );
    }

    final u = _user!;

    String? followedByText;

    if (u.followedByFollowings.isNotEmpty && !_isMe) {
      final names = u.followedByFollowings.take(3).map((e) => '@$e').toList();
      followedByText = 'Followed by ${names.join(', ')}';
    }

    return Scaffold(
      backgroundColor: p.bg,
      appBar: AppBar(
        backgroundColor: p.bg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: p.text),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '@${u.username}',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: p.text),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.more_horiz_rounded, color: p.text),
            onPressed: _profileMenu,
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                GestureDetector(
                  onTap: () {
                    if (u.id != null && u.hasUnseenStory) {
                      openUserOrStory(context, u).then((_) => _load());
                    } else if (u.avatarItems.isNotEmpty) {
                      _showAvatarsGallery();
                    }
                  },
                  child: Stack(children: [
                    Avatar(
                      url: u.avatarUrl,
                      size: 92,
                      ring: u.hasUnseenStory,
                    ),
                    if (!_isMe && u.isOnline)
                      Positioned(
                        right: 6,
                        bottom: 6,
                        child: Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: p.green,
                            shape: BoxShape.circle,
                            border: Border.all(color: p.bg, width: 3),
                          ),
                        ),
                      ),
                  ]),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Flexible(
                        child: Text(
                          u.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w900,
                            color: p.text,
                          ),
                        ),
                      ),
                      if (u.verified) ...[
                        const SizedBox(width: 6),
                        Icon(Icons.verified_rounded, size: 20, color: p.accent),
                      ],
                    ]),
                    const SizedBox(height: 2),
                    Text('@${u.username}', style: TextStyle(color: p.sub, fontSize: 13.5)),
                    if (!_isMe && u.isOnline)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          'Online',
                          style: TextStyle(
                            color: p.green,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ]),
                ),
              ]),
              const SizedBox(height: 14),
              _isMe
                  ? OutlinePillButton(
                      text: 'Edit profile',
                      icon: Icons.edit_rounded,
                      onTap: () => Navigator.push(
                        context,
                        SlideUpRoute(const EditProfileScreen()),
                      ).then((_) {
                        context.read<AppState>().fetchMe();
                        _load();
                      }),
                    )
                  : GradientButton(
                      text: _following ? 'Following ✓' : 'Follow',
                      height: 42,
                      gradient: _following ? null : p.brand,
                      outline: _following,
                      onPressed: _toggleFollow,
                    ),
              if (u.bio.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(u.bio, style: TextStyle(fontSize: 14, height: 1.4, color: p.text)),
              ],
              if (followedByText != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    followedByText,
                    style: TextStyle(
                      fontSize: 12,
                      color: p.sub,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              if (u.avatarItems.length > 1) ...[
                const SizedBox(height: 14),
                Text(
                  'Avatars',
                  style: TextStyle(color: p.sub, fontSize: 12, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  height: 70,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: u.avatarItems.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      final reversedIndex = u.avatarItems.length - 1 - i;
                      final a = u.avatarItems[reversedIndex];

                      return GestureDetector(
                        onLongPress: () => _downloadMedia(a, 'avatar_$reversedIndex.jpg'),
                        onTap: () => Navigator.push(
                          context,
                          FadeRoute(MediaViewerScreen(
                            media: a,
                            heroTag: 'av_${u.id}_$reversedIndex',
                          )),
                        ),
                        child: Stack(children: [
                          ClipOval(
                            child: CachedNetworkImage(
                              imageUrl: a.url,
                              width: 62,
                              height: 62,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => Container(color: p.card),
                            ),
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: GestureDetector(
                              onTap: () =>
                                  _downloadMedia(a, 'avatar_$reversedIndex.jpg'),
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(.6),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.download_rounded,
                                  color: Colors.white,
                                  size: 12,
                                ),
                              ),
                            ),
                          ),
                        ]),
                      );
                    },
                  ),
                ),
              ],
              if (u.musicItems.isNotEmpty) ...[
                const SizedBox(height: 14),
                GestureDetector(
                  onTap: _openMusicSheet,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: p.card,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: p.border),
                    ),
                    child: Row(children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(gradient: p.brand, shape: BoxShape.circle),
                        child: const Icon(
                          Icons.music_note_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Profile Music',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: p.sub, size: 22),
                    ]),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                _stat(u.following, 'Following'),
                Container(width: 1, height: 30, color: p.border),
                _stat(u.followers, 'Followers'),
                Container(width: 1, height: 30, color: p.border),
                _stat(u.posts, 'Posts'),
              ]),
              const SizedBox(height: 16),
            ]),
          ),
          Container(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: p.border)),
            ),
            child: Row(children: [
              _ProfileTabButton(
                label: 'Posts',
                selected: _activeTab == 0,
                onTap: () => setState(() => _activeTab = 0),
              ),
              _ProfileTabButton(
                label: 'Media',
                selected: _activeTab == 1,
                onTap: () => setState(() => _activeTab = 1),
              ),
            ]),
          ),
          _buildTabContent(),
        ],
      ),
    );
  }

  void _showAvatarsGallery() {
    if (_user == null || _user!.avatarItems.isEmpty) return;

    Navigator.push(
      context,
      FadeRoute(MediaViewerScreen(
        media: _user!.avatarItems.last,
        heroTag: 'av_${_user!.id}_latest',
      )),
    );
  }

  Future<void> _downloadMedia(MediaItem m, String name) async {
    try {
      final status = await Permission.storage.request();

      if (!status.isGranted && Platform.isAndroid) {
        final s2 = await Permission.manageExternalStorage.request();

        if (!s2.isGranted) {
          if (mounted) showSnack(context, 'Storage permission required', error: true);
          return;
        }
      }
    } catch (_) {}

    final fullUrl = _fullUrl(m.url);

    try {
      showSnack(context, 'Downloading...');

      await FileCache.instance.downloadWithResume(
        fullUrl,
        headers: authHeaders(),
      );

      if (mounted) showSnack(context, 'Saved ✓');
    } catch (e) {
      if (mounted) showSnack(context, 'Download failed', error: true);
    }
  }
}

class _MusicSheetItem extends StatefulWidget {
  final MediaItem media;

  const _MusicSheetItem({required this.media});

  @override
  State<_MusicSheetItem> createState() => _MusicSheetItemState();
}

class _MusicSheetItemState extends State<_MusicSheetItem> {
  bool _cached = false;

  @override
  void initState() {
    super.initState();
    _checkCache();
  }

  String get _title => widget.media.title?.isNotEmpty == true
      ? widget.media.title!
      : (widget.media.originalName?.isNotEmpty == true
          ? widget.media.originalName!
          : 'Audio track');

  Future<void> _checkCache() async {
    final full = _fullUrl(widget.media.url);

    if (await FileCache.instance.hasFile(full)) {
      if (mounted) setState(() => _cached = true);
    }
  }

  Future<void> _play() async {
    final audio = AudioController.instance;
    final full = _fullUrl(widget.media.url);

    if (audio.currentKey == widget.media.url) {
      if (audio.playing) {
        await audio.pause();
      } else {
        await audio.resume();
      }
      return;
    }

    try {
      String path;

      if (await FileCache.instance.hasFile(full)) {
        path = FileCache.instance.getLocalPath(full);

        if (!_cached && mounted) {
          setState(() => _cached = true);
        }
      } else {
        path = await FileCache.instance.downloadWithResume(
          full,
          headers: authHeaders(),
          onProgress: (_) {
            if (mounted) setState(() {});
          },
        );

        if (mounted) setState(() => _cached = true);
      }

      await audio.play(
        path,
        key: widget.media.url,
        title: _title,
        artist: widget.media.artist,
        duration: widget.media.duration,
      );
    } catch (_) {
      if (mounted) showSnack(context, 'Audio playback failed', error: true);
    }
  }

  Future<void> _downloadOnly() async {
    final full = _fullUrl(widget.media.url);

    try {
      await FileCache.instance.downloadWithResume(
        full,
        headers: authHeaders(),
        onProgress: (_) {
          if (mounted) setState(() {});
        },
      );

      if (mounted) {
        setState(() => _cached = true);
        showSnack(context, 'Download complete ✓');
      }
    } catch (_) {
      if (mounted) showSnack(context, 'Download failed', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _p(context);
    final audio = context.watch<AudioController>();
    final cache = context.watch<FileCache>();

    final isCurrent = audio.currentKey == widget.media.url;
    final isPlaying = isCurrent && audio.playing;

    final fullUrl = _fullUrl(widget.media.url);
    final dlProgress = cache.getProgress(fullUrl);
    final isDlActive = cache.isDownloading(fullUrl);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.border),
      ),
      child: Column(children: [
        Row(children: [
          GestureDetector(
            onTap: _play,
            child: Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                gradient: p.brand,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: p.accent.withOpacity(.3), blurRadius: 10)
                ],
              ),
              child: Icon(
                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
          if (!_cached) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: isDlActive ? null : _downloadOnly,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: p.accent.withOpacity(.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: isDlActive
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          value: dlProgress,
                          color: p.accent,
                        ),
                      )
                    : Icon(Icons.download_rounded, color: p.accent, size: 20),
              ),
            ),
          ],
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                if (widget.media.artist?.isNotEmpty == true)
                  Row(children: [
                    Icon(Icons.person_outline_rounded, size: 12, color: p.sub),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        widget.media.artist!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: p.sub),
                      ),
                    ),
                  ]),
                if (widget.media.duration != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(children: [
                      Icon(Icons.access_time_rounded, size: 12, color: p.sub),
                      const SizedBox(width: 4),
                      Text(
                        formatDuration(widget.media.duration),
                        style: TextStyle(fontSize: 12, color: p.sub),
                      ),
                    ]),
                  ),
              ],
            ),
          ),
        ]),
        if (isDlActive && !_cached)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(children: [
              Expanded(
                child: LinearProgressIndicator(
                  value: dlProgress,
                  color: p.accent,
                  backgroundColor: p.card2,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${(dlProgress * 100).toInt()}%',
                style: TextStyle(fontSize: 10, color: p.sub),
              ),
            ]),
          ),
        if (isCurrent) ...[
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              activeTrackColor: p.accent,
              inactiveTrackColor: p.card2,
              thumbColor: p.accent,
            ),
            child: Slider(
              value: audio.position.clamp(0.0, audio.currentDuration ?? 1.0),
              max: audio.currentDuration ?? 1.0,
              onChanged: (v) => audio.seekTo(v),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(
                formatDuration(audio.position),
                style: TextStyle(fontSize: 10, color: p.sub),
              ),
              Text(
                formatDuration(audio.currentDuration),
                style: TextStyle(fontSize: 10, color: p.sub),
              ),
            ]),
          ),
        ],
      ]),
    );
  }
}

class _ProfileTabButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ProfileTabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = _p(context);

    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? p.accent : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                fontSize: 14,
                color: selected ? p.text : p.sub,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileTab extends StatefulWidget {
  final Future<List<Post>> Function() loader;
  final bool loading;
  final bool grid;

  const _ProfileTab({
    required this.loader,
    required this.loading,
    required this.grid,
  });

  @override
  State<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<_ProfileTab>
    with AutomaticKeepAliveClientMixin {
  List<Post>? _items;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    final items = await widget.loader();
    if (mounted) setState(() => _items = items);
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final p = _p(context);

    if (_items == null || widget.loading) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
      );
    }

    if (_items!.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(40),
        child: EmptyState(
          icon: widget.grid ? Icons.photo_library_outlined : Icons.notes_rounded,
          title: 'Nothing here yet',
          subtitle: widget.grid
              ? 'Media will show up here.'
              : 'Posts will show up here.',
        ),
      );
    }

    if (widget.grid) {
      final withMedia = _items!.where((x) => x.media.isNotEmpty).toList();

      if (withMedia.isEmpty) {
        return const Padding(
          padding: EdgeInsets.all(40),
          child: EmptyState(
            icon: Icons.photo_library_outlined,
            title: 'No media',
            subtitle: 'Posts with media will appear here.',
          ),
        );
      }

      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(3),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 3,
          crossAxisSpacing: 3,
          childAspectRatio: .9,
        ),
        itemCount: withMedia.length,
        itemBuilder: (context, i) {
          final x = withMedia[i];

          return GestureDetector(
            onTap: () => Navigator.push(
              context,
              FadeRoute(PostDetailScreen(postId: x.id, initial: x)),
            ),
            child: Stack(fit: StackFit.expand, children: [
              CachedNetworkImage(
                imageUrl: x.media.first.thumbnail ?? x.media.first.url,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(color: p.card),
              ),
              if (x.media.first.type == 'video' || x.media.first.type == 'gif')
                const Positioned(
                  top: 8,
                  right: 8,
                  child: Icon(
                    Icons.play_circle_fill_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
            ]),
          );
        },
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 40),
      itemCount: _items!.length,
      separatorBuilder: (_, __) => Divider(
        height: 1,
        thickness: 1,
        color: p.border.withOpacity(.4),
      ),
      itemBuilder: (context, i) => PostCard(post: _items![i]),
    );
  }
}

// ═══════════════════════════════ EDIT PROFILE ════════════════════
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _api = ApiClient.instance;

  final _name = TextEditingController();
  final _bio = TextEditingController();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _saving = false;

  final List<String> _avatarIds = [];
  final List<String> _musicIds = [];

  final Map<String, double> _avatarProgress = {};
  final Map<String, double> _musicProgress = {};

  final Set<String> _uploadingAvatars = {};
  final Set<String> _uploadingMusics = {};

  @override
  void initState() {
    super.initState();

    final me = context.read<AppState>().me;

    _name.text = me?.name ?? '';
    _bio.text = me?.bio ?? '';
    _username.text = me?.username ?? '';
    _email.text = me?.email ?? '';

    if (me != null) {
      for (final a in me.avatarItems) {
        _avatarIds.add(a.id ?? a.url);
      }

      for (final m in me.musicItems) {
        _musicIds.add(m.id ?? m.url);
      }
    }
  }

  Future<void> _pickAvatar() async {
    try {
      final f = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (f == null) return;

      final tempId = 'av_${DateTime.now().microsecondsSinceEpoch}';

      setState(() {
        _avatarIds.add(tempId);
        _avatarProgress[tempId] = 0;
        _uploadingAvatars.add(tempId);
      });

      try {
        final res = await _api.uploadMedia(
          f.path,
          onProgress: (v) {
            if (mounted) setState(() => _avatarProgress[tempId] = v);
          },
        );

        String id = '';
        String? url;

        if (res is Map) {
          id = jstr(jpick(res, ['id', 'media_id']));
          url = resolveMedia(jpick(res, ['url']));
        }

        if (!mounted) return;

        setState(() {
          final idx = _avatarIds.indexOf(tempId);

          if (idx != -1) {
            _avatarIds[idx] = id.isNotEmpty ? id : (url ?? tempId);
          }

          _avatarProgress.remove(tempId);
          _uploadingAvatars.remove(tempId);
        });

        if (id.isEmpty && url == null && mounted) {
          showSnack(context, 'Avatar upload failed', error: true);
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _avatarIds.remove(tempId);
            _avatarProgress.remove(tempId);
            _uploadingAvatars.remove(tempId);
          });

          showSnack(context, 'Avatar upload failed', error: true);
        }
      }
    } catch (_) {
      if (mounted) showSnack(context, 'Avatar upload failed', error: true);
    }
  }

  Future<void> _pickMusic() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.audio);

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      if (file.path == null) return;

      final tempId = 'mu_${DateTime.now().microsecondsSinceEpoch}';

      setState(() {
        _musicIds.add(tempId);
        _musicProgress[tempId] = 0;
        _uploadingMusics.add(tempId);
      });

      try {
        final res = await _api.uploadMedia(
          file.path!,
          onProgress: (v) {
            if (mounted) setState(() => _musicProgress[tempId] = v);
          },
        );

        String id = '';
        String? url;

        if (res is Map) {
          id = jstr(jpick(res, ['id', 'media_id']));
          url = resolveMedia(jpick(res, ['url']));
        }

        if (!mounted) return;

        setState(() {
          final idx = _musicIds.indexOf(tempId);

          if (idx != -1) {
            _musicIds[idx] = id.isNotEmpty ? id : (url ?? tempId);
          }

          _musicProgress.remove(tempId);
          _uploadingMusics.remove(tempId);
        });

        if (id.isEmpty && url == null && mounted) {
          showSnack(context, 'Music upload failed', error: true);
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _musicIds.remove(tempId);
            _musicProgress.remove(tempId);
            _uploadingMusics.remove(tempId);
          });

          showSnack(context, 'Music upload failed', error: true);
        }
      }
    } catch (_) {
      if (mounted) showSnack(context, 'Music upload failed', error: true);
    }
  }

  Future<void> _save() async {
    if (_saving) return;

    if (_uploadingAvatars.isNotEmpty || _uploadingMusics.isNotEmpty) {
      showSnack(context, 'Wait for uploads to finish', error: true);
      return;
    }

    setState(() => _saving = true);

    try {
      final body = <String, dynamic>{
        'name': _name.text.trim(),
        'bio': _bio.text.trim(),
        if (_username.text.trim().isNotEmpty) 'username': _username.text.trim(),
        if (_email.text.trim().isNotEmpty) 'email': _email.text.trim(),
        if (_password.text.isNotEmpty) 'password': _password.text,
        if (_avatarIds.isNotEmpty) 'profile_image_ids': _avatarIds,
        if (_musicIds.isNotEmpty) 'profile_music_ids': _musicIds,
      };

      await _api.put('/api/users/me', body: body);
      await context.read<AppState>().fetchMe();

      if (mounted) {
        showSnack(context, 'Profile updated ✨');
        Navigator.pop(context);
      }
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _bio.dispose();
    _username.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Widget _field(
    String label,
    TextEditingController c, {
    int lines = 1,
    bool obscure = false,
    String? hint,
  }) {
    final p = _p(context);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(
        label,
        style: TextStyle(color: p.sub, fontSize: 12.5, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 6),
      TextField(
        controller: c,
        maxLines: lines,
        obscureText: obscure,
        style: TextStyle(fontSize: 14.5, color: p.text),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: p.sub, fontSize: 13),
          filled: true,
          fillColor: p.card,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: p.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: p.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: p.accent, width: 1.3),
          ),
        ),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    _applyBars(context);

    final p = _p(context);
    final me = context.watch<AppState>().me;

    return Scaffold(
      backgroundColor: p.bg,
      appBar: AppBar(
        title: const Text(
          'Edit profile',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GradientButton(
              text: 'Save',
              width: 92,
              height: 40,
              loading: _saving,
              onPressed: _saving ? null : _save,
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          GestureDetector(
            onTap: _pickAvatar,
            child: Stack(alignment: Alignment.center, children: [
              Avatar(
                url: me?.avatarUrl,
                size: 96,
                ring: me?.hasUnseenStory ?? false,
              ),
              Positioned(
                right: 2,
                bottom: 2,
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    gradient: p.brand,
                    shape: BoxShape.circle,
                    border: Border.all(color: p.bg, width: 2),
                  ),
                  child: const Icon(Icons.photo_camera_rounded, size: 15, color: Colors.white),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 6),
          Text(
            'Tap to add another avatar',
            style: TextStyle(color: p.sub, fontSize: 12),
          ),
          if (_avatarIds.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 70,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _avatarIds.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final id = _avatarIds[i];

                  final isUploading = _uploadingAvatars.contains(id);
                  final progress = _avatarProgress[id] ?? 0;

                  return Stack(children: [
                    ClipOval(
                      child: SizedBox(
                        width: 60,
                        height: 60,
                        child: isUploading
                            ? Container(
                                color: p.card,
                                child: Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      SizedBox(
                                        width: 28,
                                        height: 28,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.4,
                                          value: progress,
                                          color: p.accent,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${(progress * 100).toInt()}%',
                                        style: TextStyle(fontSize: 9, color: p.sub),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : CachedNetworkImage(
                                imageUrl: resolveMedia(id) ?? id,
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) => Container(
                                  color: p.card,
                                  child: Icon(Icons.person_rounded, color: p.sub),
                                ),
                              ),
                      ),
                    ),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _avatarIds.removeAt(i);
                          _avatarProgress.remove(id);
                          _uploadingAvatars.remove(id);
                        }),
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(.7),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            size: 12,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ]);
                },
              ),
            ),
          ],
          const SizedBox(height: 14),
          GradientButton(
            text: 'Add profile music',
            icon: Icons.audiotrack_rounded,
            onPressed: _pickMusic,
          ),
          if (_musicIds.isNotEmpty) ...[
            const SizedBox(height: 12),
            ..._musicIds.map((id) {
              final isUploading = _uploadingMusics.contains(id);
              final progress = _musicProgress[id] ?? 0;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: p.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: p.border),
                ),
                child: Row(children: [
                  Icon(Icons.audiotrack_rounded, color: p.accent, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: isUploading
                        ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(
                              'Uploading music…',
                              style: TextStyle(fontSize: 12, color: p.text),
                            ),
                            LinearProgressIndicator(value: progress, color: p.accent),
                          ])
                        : Text(
                            'Music track ${_musicIds.indexOf(id) + 1}',
                            style: TextStyle(fontSize: 12, color: p.text),
                          ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() {
                      _musicIds.remove(id);
                      _musicProgress.remove(id);
                      _uploadingMusics.remove(id);
                    }),
                    child: Icon(Icons.close_rounded, color: p.sub, size: 18),
                  ),
                ]),
              );
            }),
          ],
          const SizedBox(height: 22),
          _field('Display name', _name),
          const SizedBox(height: 14),
          _field('Bio', _bio, lines: 3),
          const SizedBox(height: 14),
          _field('Username', _username),
          const SizedBox(height: 14),
          _field('Email', _email),
          const SizedBox(height: 14),
          _field(
            'New password',
            _password,
            obscure: true,
            hint: 'Leave blank to keep current',
          ),
          const SizedBox(height: 30),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════ SETTINGS ════════════════════════
void openSettings(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => const _SettingsSheet(),
  );
}

class _SettingsSheet extends StatefulWidget {
  const _SettingsSheet();

  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  bool _refreshing = false;

  Future<void> _refreshLink() async {
    setState(() => _refreshing = true);

    try {
      final url = await ApiClient.instance.fetchBaseUrl(force: true);

      if (mounted) {
        setState(() {});
        showSnack(context, 'Link updated: $url');
      }
    } catch (_) {
      if (mounted) showSnack(context, 'Could not refresh the link', error: true);
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _p(context);

    final base = ApiClient.instance.baseUrl ?? 'unknown';
    final theme = context.watch<ThemeStore>();

    return Container(
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: p.border,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 18),
            Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: p.accent.withOpacity(.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.dns_rounded, color: p.accent),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text(
                    'Server link (dynamic)',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    base,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: p.sub, fontSize: 12),
                  ),
                ]),
              ),
            ]),
            const SizedBox(height: 14),
            GradientButton(
              text: 'Refresh server link',
              icon: Icons.refresh_rounded,
              loading: _refreshing,
              onPressed: _refreshing ? null : _refreshLink,
            ),
            const SizedBox(height: 14),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                theme.isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                color: p.accent,
              ),
              title: const Text(
                'Theme',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
              ),
              subtitle: Text(
                theme.isDark ? 'Dark mode' : 'Light mode',
                style: TextStyle(color: p.sub, fontSize: 12),
              ),
              trailing: Switch(
                value: theme.isDark,
                onChanged: (_) => theme.toggle(),
                activeColor: p.accent,
              ),
            ),
            const SizedBox(height: 8),
            Container(height: 1, color: p.border),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.logout_rounded, color: p.red),
              title: Text(
                'Log out',
                style: TextStyle(color: p.red, fontWeight: FontWeight.w800, fontSize: 14.5),
              ),
              onTap: () async {
                Navigator.pop(context);

                await context.read<AppState>().logout();

                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    FadeRoute(const AuthScreen()),
                    (_) => false,
                  );
                }
              },
            ),
            Center(
              child: Text(
                'NokhodX v4.2.0',
                style: TextStyle(color: p.sub, fontSize: 11),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ═══════════════════════════════ MEDIA VIEWER ═════════════════════
class MediaViewerScreen extends StatelessWidget {
  final MediaItem media;
  final String heroTag;

  const MediaViewerScreen({
    super.key,
    required this.media,
    required this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Stack(fit: StackFit.expand, children: [
          Hero(
            tag: heroTag,
            child: PhotoView(
              imageProvider: CachedNetworkImageProvider(media.url),
              minScale: PhotoViewComputedScale.contained,
              maxScale: PhotoViewComputedScale.covered * 3,
              backgroundDecoration: const BoxDecoration(color: Colors.black),
              loadingBuilder: (_, __) => const Center(
                child: CircularProgressIndicator(),
              ),
              errorBuilder: (_, __, ___) => const Center(
                child: Icon(
                  Icons.broken_image_rounded,
                  color: Colors.white54,
                  size: 44,
                ),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 6,
            right: 12,
            child: Row(children: [
              _DownloadButton(url: media.url, name: media.originalName ?? 'image'),
              const SizedBox(width: 10),
              _circleBtn(Icons.close_rounded, () => Navigator.pop(context)),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _circleBtn(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(.5),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      );
}

class _DownloadButton extends StatefulWidget {
  final String url;
  final String name;

  const _DownloadButton({required this.url, required this.name});

  @override
  State<_DownloadButton> createState() => _DownloadButtonState();
}

class _DownloadButtonState extends State<_DownloadButton> {
  double _progress = 0;
  bool _downloading = false;

  Future<void> _download() async {
    if (_downloading) return;

    try {
      final status = await Permission.storage.request();

      if (!status.isGranted && Platform.isAndroid) {
        final s2 = await Permission.manageExternalStorage.request();

        if (!s2.isGranted) {
          if (mounted) showSnack(context, 'Storage permission required', error: true);
          return;
        }
      }
    } catch (_) {}

    setState(() => _downloading = true);

    final fullUrl = _fullUrl(widget.url);

    try {
      final path = await FileCache.instance.downloadWithResume(
        fullUrl,
        onProgress: (v) {
          if (mounted) setState(() => _progress = v);
        },
        headers: authHeaders(),
      );

      if (mounted) {
        setState(() => _downloading = false);
        showSnack(context, 'Saved ✓');
        OpenFile.open(path);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _downloading = false);
        showSnack(context, 'Download failed', error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cache = context.watch<FileCache>();
    final fullUrl = _fullUrl(widget.url);

    final cacheProgress = cache.getProgress(fullUrl);
    final isCacheActive = cache.isDownloading(fullUrl);

    final displayProgress = _progress > 0 ? _progress : cacheProgress;

    return GestureDetector(
      onTap: _downloading || isCacheActive ? null : _download,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(.5),
          shape: BoxShape.circle,
        ),
        child: (_downloading || isCacheActive)
            ? Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    value: displayProgress,
                    color: Colors.white,
                  ),
                ),
              )
            : const Icon(Icons.download_rounded, color: Colors.white, size: 20),
      ),
    );
  }
}

// ═══════════════════════════════ FULL SCREEN VIDEO ════════════════
class FullScreenVideoScreen extends StatefulWidget {
  final String url;
  final String? thumbnail;

  const FullScreenVideoScreen({super.key, required this.url, this.thumbnail});

  @override
  State<FullScreenVideoScreen> createState() => _FullScreenVideoScreenState();
}

class _FullScreenVideoScreenState extends State<FullScreenVideoScreen> {
  VideoPlayerController? _c;

  bool _ready = false;
  bool _error = false;
  bool _showControls = true;
  bool _caching = false;
  double _cacheProgress = 0;

  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    applySystemUIStyle(ThemeStore.instance.isDark);
    AudioController.instance.muteTemporarily();

    _init();
  }

  Future<void> _init() async {
    final fullUrl = _fullUrl(widget.url);

    setState(() => _caching = true);

    try {
      final localPath = await FileCache.instance.downloadWithResume(
        fullUrl,
        onProgress: (v) {
          if (mounted) setState(() => _cacheProgress = v);
        },
        headers: authHeaders(),
      );

      if (!mounted) return;

      final file = File(localPath);

      if (await file.exists()) {
        final c = VideoPlayerController.file(file);
        _c = c;

        await c.initialize();
        c.setLooping(true);
        await c.play();

        if (mounted) {
          setState(() {
            _ready = true;
            _caching = false;
          });
        }
      } else {
        throw Exception('File not found');
      }
    } catch (_) {
      try {
        final c = VideoPlayerController.networkUrl(Uri.parse(fullUrl));
        _c = c;

        await c.initialize();
        c.setLooping(true);
        await c.play();

        if (mounted) {
          setState(() {
            _ready = true;
            _caching = false;
          });
        }
      } catch (__) {
        if (mounted) {
          setState(() {
            _error = true;
            _caching = false;
          });
        }
      }
    }
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    _hideTimer?.cancel();

    if (_showControls) {
      _hideTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => _showControls = false);
      });
    }
  }

  @override
  void dispose() {
    AudioController.instance.unmute();

    _hideTimer?.cancel();
    _c?.dispose();

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    applySystemUIStyle(ThemeStore.instance.isDark);

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.videocam_off_rounded, color: Colors.white54, size: 60),
              SizedBox(height: 12),
              Text(
                'Video unavailable',
                style: TextStyle(color: Colors.white54, fontSize: 16),
              ),
            ]),
          ),
        ),
      );
    }

    if (_caching) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (widget.thumbnail != null && widget.thumbnail!.isNotEmpty)
              SizedBox(
                width: 200,
                height: 120,
                child: CachedNetworkImage(
                  imageUrl: widget.thumbnail!,
                  fit: BoxFit.cover,
                ),
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: 50,
              height: 50,
              child: CircularProgressIndicator(
                value: _cacheProgress > 0 ? _cacheProgress : null,
                color: Colors.white,
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Loading video... ${(_cacheProgress * 100).toInt()}%',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ]),
        ),
      );
    }

    if (!_ready || _c == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleControls,
        child: Stack(fit: StackFit.expand, children: [
          Center(
            child: AspectRatio(
              aspectRatio: _c!.value.aspectRatio,
              child: VideoPlayer(_c!),
            ),
          ),
          if (_showControls) ...[
            Positioned.fill(child: Container(color: Colors.black.withOpacity(.3))),
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              left: 16,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(.6),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_back_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 20,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  VideoProgressIndicator(
                    _c!,
                    allowScrubbing: true,
                    colors: VideoProgressColors(
                      playedColor: const Color(0xFFF91880),
                      bufferedColor: Colors.white24,
                      backgroundColor: Colors.white10,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    GestureDetector(
                      onTap: () {
                        final cur =
                            _c!.value.position - const Duration(seconds: 10);

                        _c!.seekTo(cur < Duration.zero ? Duration.zero : cur);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(.5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.replay_10_rounded,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                    ),
                    const SizedBox(width: 24),
                    GestureDetector(
                      onTap: () => setState(
                        () => _c!.value.isPlaying ? _c!.pause() : _c!.play(),
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(.6),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _c!.value.isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                    ),
                    const SizedBox(width: 24),
                    GestureDetector(
                      onTap: () {
                        final cur =
                            _c!.value.position + const Duration(seconds: 10);

                        _c!.seekTo(cur);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(.5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.forward_10_rounded,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                    ),
                  ]),
                ]),
              ),
            ),
          ],
        ]),
      ),
    );
  }
}

// ═══════════════════════════════ COMMON ══════════════════════════
class Avatar extends StatelessWidget {
  final String? url;
  final double size;
  final bool ring;
  final String? fallback;

  const Avatar({
    super.key,
    this.url,
    required this.size,
    this.ring = false,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    final p = _p(context);

    final inner = ClipOval(
      child: (url != null && url!.isNotEmpty)
          ? CachedNetworkImage(
              imageUrl: url!,
              width: size,
              height: size,
              fit: BoxFit.cover,
              placeholder: (_, __) => _placeholder(p),
              errorWidget: (_, __, ___) => _placeholder(p),
            )
          : _placeholder(p),
    );

    if (!ring) return SizedBox(width: size, height: size, child: inner);

    return Container(
      width: size + 4,
      height: size + 4,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(shape: BoxShape.circle, gradient: p.reel),
      child: ClipOval(child: inner),
    );
  }

  Widget _placeholder(Pal p) {
    final letter = (fallback != null && fallback!.isNotEmpty) ? fallback![0] : '?';

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(gradient: p.brand),
      alignment: Alignment.center,
      child: Text(
        letter.toUpperCase(),
        style: TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: size * .42,
          color: Colors.white,
        ),
      ),
    );
  }
}

class GradientButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool loading;
  final LinearGradient? gradient;
  final double height;
  final double? width;
  final IconData? icon;
  final bool outline;

  const GradientButton({
    super.key,
    required this.text,
    this.onPressed,
    this.loading = false,
    this.gradient,
    this.height = 50,
    this.width,
    this.icon,
    this.outline = false,
  });

  @override
  State<GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<GradientButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final p = _p(context);
    final disabled = widget.onPressed == null || widget.loading;

    return Listener(
      onPointerDown: (_) => setState(() => _pressed = true),
      onPointerUp: (_) => setState(() => _pressed = false),
      onPointerCancel: (_) => setState(() => _pressed = false),
      child: GestureDetector(
        onTap: disabled ? null : widget.onPressed,
        child: AnimatedScale(
          scale: _pressed && !disabled ? .95 : 1,
          duration: const Duration(milliseconds: 140),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            height: widget.height,
            width: widget.width ?? double.infinity,
            padding: widget.width != null
                ? const EdgeInsets.symmetric(horizontal: 14)
                : null,
            decoration: BoxDecoration(
              gradient: widget.outline ? null : (widget.gradient ?? p.brand),
              color: widget.outline ? Colors.transparent : null,
              border: widget.outline ? Border.all(color: p.border, width: 1.4) : null,
              borderRadius: BorderRadius.circular(widget.height / 2),
              boxShadow: widget.outline || disabled
                  ? null
                  : [BoxShadow(color: p.accent.withOpacity(.35), blurRadius: 18)],
            ),
            child: Center(
              child: widget.loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : Row(mainAxisSize: MainAxisSize.min, children: [
                      if (widget.icon != null) ...[
                        Icon(
                          widget.icon,
                          size: 18,
                          color: widget.outline ? p.text : Colors.white,
                        ),
                        const SizedBox(width: 7),
                      ],
                      Text(
                        widget.text,
                        style: TextStyle(
                          color: widget.outline ? p.text : Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 14.5,
                          letterSpacing: .2,
                        ),
                      ),
                    ]),
            ),
          ),
        ),
      ),
    );
  }
}

class OutlinePillButton extends StatelessWidget {
  final String text;
  final IconData? icon;
  final VoidCallback onTap;

  const OutlinePillButton({
    super.key,
    required this.text,
    this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = _p(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(21),
          border: Border.all(color: p.border, width: 1.4),
          color: p.surface,
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[
            Icon(icon, size: 17, color: p.text),
            const SizedBox(width: 7),
          ],
          Text(
            text,
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: p.text),
          ),
        ]),
      ),
    );
  }
}

class FollowButton extends StatefulWidget {
  final User user;
  final bool compact;

  const FollowButton({super.key, required this.user, this.compact = false});

  @override
  State<FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends State<FollowButton> {
  late bool _following = widget.user.isFollowing;
  bool _busy = false;

  Future<void> _toggle() async {
    if (_busy) return;

    setState(() {
      _busy = true;
      _following = !_following;
    });

    try {
      await ApiClient.instance.post('/api/users/${widget.user.username}/follow');
    } catch (e) {
      if (mounted) {
        setState(() => _following = !_following);
        showSnack(context, e.toString(), error: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _p(context);

    return GestureDetector(
      onTap: _toggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: EdgeInsets.symmetric(
          horizontal: widget.compact ? 14 : 20,
          vertical: widget.compact ? 5 : 8,
        ),
        decoration: BoxDecoration(
          gradient: _following ? null : p.brand,
          color: _following ? Colors.transparent : null,
          border: _following ? Border.all(color: p.border, width: 1.3) : null,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          _following ? 'Following' : 'Follow',
          style: TextStyle(
            fontSize: widget.compact ? 11.5 : 13,
            fontWeight: FontWeight.w800,
            color: _following ? p.text : Colors.white,
          ),
        ),
      ),
    );
  }
}

class SlideFadeIn extends StatefulWidget {
  final Widget child;
  final Duration delay;

  const SlideFadeIn({super.key, required this.child, this.delay = Duration.zero});

  @override
  State<SlideFadeIn> createState() => _SlideFadeInState();
}

class _SlideFadeInState extends State<SlideFadeIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  @override
  void initState() {
    super.initState();

    Future.delayed(widget.delay, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);

    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, .05), end: Offset.zero).animate(curved),
        child: widget.child,
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final p = _p(context);

    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 86,
          height: 86,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: p.accent.withOpacity(.1),
          ),
          child: Icon(icon, size: 40, color: p.accent),
        ),
        const SizedBox(height: 18),
        Text(
          title,
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: p.text),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(color: p.sub, fontSize: 13),
        ),
      ]),
    );
  }
}

class ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const ErrorState({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final p = _p(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.cloud_off_rounded, size: 44, color: p.sub),
          const SizedBox(height: 14),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: p.sub, fontSize: 13.5),
          ),
          const SizedBox(height: 18),
          GradientButton(
            text: 'Try again',
            icon: Icons.refresh_rounded,
            width: 180,
            height: 44,
            onPressed: onRetry,
          ),
        ]),
      ),
    );
  }
}

class ShimmerBlock extends StatelessWidget {
  final double height;

  const ShimmerBlock({super.key, required this.height});

  @override
  Widget build(BuildContext context) {
    final p = _p(context);

    return Shimmer.fromColors(
      baseColor: p.card,
      highlightColor: p.card2,
      child: Container(
        height: height,
        decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}

class ShimmerPost extends StatelessWidget {
  const ShimmerPost({super.key});

  @override
  Widget build(BuildContext context) {
    final p = _p(context);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ShimmerCircle(size: 44, p: p),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              ShimmerCircle(size: 12, p: p),
              const SizedBox(width: 8),
              Expanded(child: ShimmerBlock(height: 12)),
            ]),
            const SizedBox(height: 10),
            const ShimmerBlock(height: 12),
            const SizedBox(height: 6),
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: .6,
              child: const ShimmerBlock(height: 12),
            ),
            const SizedBox(height: 12),
            const ShimmerBlock(height: 140),
          ]),
        ),
      ]),
    );
  }
}

class ShimmerCircle extends StatelessWidget {
  final double size;
  final Pal p;

  const ShimmerCircle({super.key, required this.size, required this.p});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: p.card,
      highlightColor: p.card2,
      child: Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
      ),
    );
  }
}