import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';

class Song {
  final String id, title, artist, audioUrl, coverUrl;
  const Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.audioUrl,
    this.coverUrl = '',
  });

  factory Song.fromMap(Map<String, dynamic> m) => Song(
        id: m['id'].toString(),
        title: (m['title'] ?? '').toString(),
        artist: (m['artist'] ?? '').toString(),
        audioUrl: (m['audio_url'] ?? '').toString(),
        coverUrl: (m['cover_url'] ?? '').toString(),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'artist': artist,
        'audio_url': audioUrl,
        'cover_url': coverUrl,
      };
}

/// Sesión de administrador (modo desarrollador)
class Admin {
  static SupabaseClient get _c => Supabase.instance.client;

  static bool get isAdmin =>
      (_c.auth.currentUser?.email ?? '').toLowerCase() ==
      Config.adminEmail.toLowerCase();

  static String? get token => _c.auth.currentSession?.accessToken;

  static Future<void> signIn(String email, String password) async {
    await _c.auth.signInWithPassword(email: email.trim(), password: password);
    if (!isAdmin) {
      await _c.auth.signOut();
      throw Exception('Esta cuenta no es de administrador');
    }
  }

  static Future<void> signOut() => _c.auth.signOut();
}

/// Canciones en Supabase + archivos en Cloudflare R2
class SongRepo {
  static SupabaseClient get _db => Supabase.instance.client;

  static Future<List<Song>> fetch() async {
    final rows =
        await _db.from('songs').select().order('created_at', ascending: false);
    return rows.map<Song>((e) => Song.fromMap(e)).toList();
  }

  static Future<String> upload(String key, Uint8List bytes, String mime) async {
    final res = await http.put(
      Uri.parse('${Config.uploadWorkerUrl}/$key'),
      headers: {
        'Authorization': 'Bearer ${Admin.token}',
        'Content-Type': mime,
      },
      body: bytes,
    );
    if (res.statusCode != 200) {
      throw Exception('Error ${res.statusCode}: ${res.body}');
    }
    return '${Config.r2PublicUrl}/$key';
  }

  static Future<void> add(
      String title, String artist, String audioUrl, String coverUrl) async {
    await _db.from('songs').insert({
      'title': title,
      'artist': artist,
      'audio_url': audioUrl,
      'cover_url': coverUrl,
    });
  }

  static Future<void> delete(Song s) async {
    for (final url in [s.audioUrl, s.coverUrl]) {
      if (url.startsWith(Config.r2PublicUrl)) {
        final key = url.substring(Config.r2PublicUrl.length + 1);
        await http.delete(
          Uri.parse('${Config.uploadWorkerUrl}/$key'),
          headers: {'Authorization': 'Bearer ${Admin.token}'},
        );
      }
    }
    await _db.from('songs').delete().eq('id', s.id);
  }
}

/// Canciones descargadas en el teléfono
class Downloads extends ChangeNotifier {
  Downloads._();
  static final Downloads instance = Downloads._();

  final Map<String, String> _paths = {};
  final Map<String, Song> _songs = {};
  final Map<String, double> progress = {};
  late SharedPreferences _prefs;

  List<Song> get songs => _songs.values.toList();
  bool isDownloaded(String id) => _paths.containsKey(id);
  String? pathOf(String id) => _paths[id];

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs.getString('downloads');
    if (raw == null) return;
    for (final e in jsonDecode(raw) as List) {
      final m = Map<String, dynamic>.from(e as Map);
      final path = m['path'] as String;
      if (File(path).existsSync()) {
        final s = Song.fromMap(m);
        _songs[s.id] = s;
        _paths[s.id] = path;
      }
    }
  }

  Future<void> _save() => _prefs.setString(
        'downloads',
        jsonEncode(_songs.values
            .map((s) => {...s.toMap(), 'path': _paths[s.id]})
            .toList()),
      );

  Future<void> download(Song s) async {
    if (isDownloaded(s.id) || progress.containsKey(s.id)) return;
    final dir = await getApplicationDocumentsDirectory();
    final clean = s.audioUrl.split('?').first;
    final ext = clean.contains('.') ? clean.split('.').last : 'mp3';
    final path = '${dir.path}/${s.id}.$ext';
    progress[s.id] = 0;
    notifyListeners();
    try {
      await Dio().download(s.audioUrl, path, onReceiveProgress: (r, t) {
        if (t > 0) {
          progress[s.id] = r / t;
          notifyListeners();
        }
      });
      _paths[s.id] = path;
      _songs[s.id] = s;
      await _save();
    } catch (e) {
      try {
        File(path).deleteSync();
      } catch (_) {}
      rethrow;
    } finally {
      progress.remove(s.id);
      notifyListeners();
    }
  }

  Future<void> remove(Song s) async {
    final path = _paths.remove(s.id);
    _songs.remove(s.id);
    if (path != null) {
      try {
        File(path).deleteSync();
      } catch (_) {}
    }
    await _save();
    notifyListeners();
  }
}

/// Reproductor (con notificación y segundo plano)
class PlayerService {
  PlayerService._() {
    player.currentIndexStream.listen((i) {
      if (i != null && i >= 0 && i < _queue.length) {
        current.value = _queue[i];
      }
    });
  }
  static final PlayerService instance = PlayerService._();

  final AudioPlayer player = AudioPlayer();
  final ValueNotifier<Song?> current = ValueNotifier<Song?>(null);
  List<Song> _queue = [];

  Future<void> playQueue(List<Song> songs, int index) async {
    _queue = songs;
    current.value = songs[index];
    final sources = songs.map((s) {
      final local = Downloads.instance.pathOf(s.id);
      final uri = local != null ? Uri.file(local) : Uri.parse(s.audioUrl);
      return AudioSource.uri(
        uri,
        tag: MediaItem(
          id: s.id,
          title: s.title,
          artist: s.artist,
          artUri: s.coverUrl.isEmpty ? null : Uri.parse(s.coverUrl),
        ),
      );
    }).toList();
    try {
      await player.setAudioSource(
        ConcatenatingAudioSource(children: sources),
        initialIndex: index,
      );
      player.play();
    } catch (_) {
      // sin conexión o archivo no disponible
    }
  }
}
