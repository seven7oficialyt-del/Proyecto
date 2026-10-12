import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'services.dart';
import 'widgets.dart';

String mimeFor(String ext) =>
    const {
      'mp3': 'audio/mpeg',
      'm4a': 'audio/mp4',
      'aac': 'audio/aac',
      'ogg': 'audio/ogg',
      'opus': 'audio/ogg',
      'wav': 'audio/wav',
      'flac': 'audio/flac',
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'webp': 'image/webp',
    }[ext] ??
    'application/octet-stream';

class AdminLoginDialog extends StatefulWidget {
  const AdminLoginDialog({super.key});

  @override
  State<AdminLoginDialog> createState() => _AdminLoginDialogState();
}

class _AdminLoginDialogState extends State<AdminLoginDialog> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _busy = false;
  String? _error;

  Future<void> _login() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Admin.signIn(_email.text, _pass.text);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        _busy = false;
        _error = 'No se pudo entrar. Revisa correo y contraseña.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Modo desarrollador'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Correo'),
          ),
          TextField(
            controller: _pass,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Contraseña'),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_error!,
                  style: const TextStyle(color: Colors.redAccent)),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _busy ? null : _login,
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Entrar'),
        ),
      ],
    );
  }
}

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final _title = TextEditingController();
  final _artist = TextEditingController();
  PlatformFile? _audio;
  PlatformFile? _cover;
  bool _busy = false;
  String _status = '';
  List<Song> _mine = [];

  @override
  void initState() {
    super.initState();
    _loadList();
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _loadList() async {
    try {
      final s = await SongRepo.fetch();
      if (mounted) setState(() => _mine = s);
    } catch (_) {}
  }

  Future<void> _pickAudio() async {
    final r = await FilePicker.platform
        .pickFiles(type: FileType.audio, withData: true);
    if (r == null) return;
    setState(() {
      _audio = r.files.single;
      if (_title.text.isEmpty) {
        _title.text = _audio!.name.replaceAll(RegExp(r'\.[^.]+$'), '');
      }
    });
  }

  Future<void> _pickCover() async {
    final r = await FilePicker.platform
        .pickFiles(type: FileType.image, withData: true);
    if (r == null) return;
    setState(() => _cover = r.files.single);
  }

  Future<void> _upload() async {
    if (_audio?.bytes == null ||
        _title.text.trim().isEmpty ||
        _artist.text.trim().isEmpty) {
      _snack('Falta elegir la canción, el título o el artista');
      return;
    }
    setState(() {
      _busy = true;
      _status = 'Subiendo canción…';
    });
    try {
      final id = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
      final aExt = (_audio!.extension ?? 'mp3').toLowerCase();
      final audioUrl = await SongRepo.upload(
          'canciones/$id.$aExt', _audio!.bytes!, mimeFor(aExt));

      var coverUrl = '';
      if (_cover?.bytes != null) {
        setState(() => _status = 'Subiendo portada…');
        final cExt = (_cover!.extension ?? 'jpg').toLowerCase();
        coverUrl = await SongRepo.upload(
            'portadas/$id.$cExt', _cover!.bytes!, mimeFor(cExt));
      }

      setState(() => _status = 'Guardando…');
      await SongRepo.add(
          _title.text.trim(), _artist.text.trim(), audioUrl, coverUrl);

      _title.clear();
      _artist.clear();
      setState(() {
        _audio = null;
        _cover = null;
      });
      _snack('¡Canción subida!');
      _loadList();
    } catch (e) {
      _snack('Error: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(Song s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('¿Eliminar canción?'),
        content: Text('${s.title} — ${s.artist}'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Eliminar')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await SongRepo.delete(s);
      _loadList();
    } catch (e) {
      _snack('No se pudo eliminar: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Modo desarrollador'),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            icon: const Icon(Icons.logout_rounded),
            onPressed: () async {
              await Admin.signOut();
              if (mounted) Navigator.pop(context);
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Subir canción',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _busy ? null : _pickAudio,
            icon: const Icon(Icons.audio_file_rounded),
            label: Text(_audio == null ? 'Elegir canción' : _audio!.name,
                overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _busy ? null : _pickCover,
            icon: const Icon(Icons.image_rounded),
            label: Text(
                _cover == null ? 'Elegir portada (opcional)' : _cover!.name,
                overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _title,
            decoration: const InputDecoration(labelText: 'Título'),
          ),
          TextField(
            controller: _artist,
            decoration: const InputDecoration(labelText: 'Artista'),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _busy ? null : _upload,
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.cloud_upload_rounded),
            label: Text(_busy ? _status : 'Subir'),
          ),
          const SizedBox(height: 28),
          Text('Canciones subidas (${_mine.length})',
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          for (final s in _mine)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Cover(s.coverUrl),
              title: Text(s.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(s.artist,
                  style: const TextStyle(color: Colors.white60)),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline_rounded,
                    color: Colors.redAccent),
                onPressed: () => _delete(s),
              ),
            ),
        ],
      ),
    );
  }
}
