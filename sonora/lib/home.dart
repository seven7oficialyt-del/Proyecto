import 'package:flutter/material.dart';

import 'admin.dart';
import 'now_playing.dart';
import 'services.dart';
import 'widgets.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;
  List<Song> _songs = [];
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      final s = await SongRepo.fetch();
      if (!mounted) return;
      setState(() {
        _songs = s;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = true;
      });
    }
  }

  Future<void> _openAdmin() async {
    if (!Admin.isAdmin) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => const AdminLoginDialog(),
      );
      if (ok != true || !mounted) return;
    }
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const AdminScreen()));
    _load();
  }

  void _openPlayer() {
    Navigator.of(context).push(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => const NowPlayingScreen(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final tabs = <Widget>[
      _HomeTab(
          songs: _songs, loading: _loading, error: _error, onRefresh: _load),
      _SearchTab(songs: _songs),
      const _DownloadsTab(),
    ];
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset('assets/icon.png',
                        width: 32, height: 32),
                  ),
                  const SizedBox(width: 10),
                  const Text('Sonora',
                      style:
                          TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Modo desarrollador',
                    icon: const Icon(Icons.admin_panel_settings_outlined),
                    onPressed: _openAdmin,
                  ),
                ],
              ),
            ),
            Expanded(child: IndexedStack(index: _tab, children: tabs)),
          ],
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          MiniPlayer(onTap: _openPlayer),
          NavigationBar(
            selectedIndex: _tab,
            onDestinationSelected: (i) => setState(() => _tab = i),
            destinations: const [
              NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home_rounded),
                  label: 'Inicio'),
              NavigationDestination(
                  icon: Icon(Icons.search_rounded),
                  selectedIcon: Icon(Icons.search_rounded),
                  label: 'Buscar'),
              NavigationDestination(
                  icon: Icon(Icons.download_for_offline_outlined),
                  selectedIcon: Icon(Icons.download_for_offline),
                  label: 'Descargas'),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
        child: Text(text,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
      );
}

class _HomeTab extends StatelessWidget {
  final List<Song> songs;
  final bool loading;
  final bool error;
  final Future<void> Function() onRefresh;
  const _HomeTab({
    required this.songs,
    required this.loading,
    required this.error,
    required this.onRefresh,
  });

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Buenos días';
    if (h < 19) return 'Buenas tardes';
    return 'Buenas noches';
  }

  @override
  Widget build(BuildContext context) {
    if (loading && songs.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    final ps = PlayerService.instance;
    final recent = songs.length > 10 ? 10 : songs.length;
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 12),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text(_greeting,
                style:
                    const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
          ),
          if (error && songs.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'No se pudo cargar la música. Revisa tu conexión y desliza hacia abajo para reintentar, o entra a Descargas.',
                style: TextStyle(color: Colors.white60),
              ),
            ),
          if (!error && songs.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Aún no hay canciones. Sube la primera desde el modo desarrollador (icono de arriba a la derecha).',
                style: TextStyle(color: Colors.white60),
              ),
            ),
          if (songs.isNotEmpty) ...[
            const _SectionTitle('Recién subidas'),
            SizedBox(
              height: 205,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: recent,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (_, i) => _SongCard(
                  song: songs[i],
                  onTap: () => ps.playQueue(songs, i),
                ),
              ),
            ),
            const _SectionTitle('Todas las canciones'),
            for (var i = 0; i < songs.length; i++)
              SongTile(song: songs[i], onTap: () => ps.playQueue(songs, i)),
          ],
        ],
      ),
    );
  }
}

class _SongCard extends StatelessWidget {
  final Song song;
  final VoidCallback onTap;
  const _SongCard({required this.song, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 140,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Cover(song.coverUrl, size: 140, radius: 8),
            const SizedBox(height: 8),
            Text(song.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            Text(song.artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white60, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _SearchTab extends StatefulWidget {
  final List<Song> songs;
  const _SearchTab({required this.songs});

  @override
  State<_SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends State<_SearchTab> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final res = widget.songs
        .where((s) =>
            s.title.toLowerCase().contains(_q) ||
            s.artist.toLowerCase().contains(_q))
        .toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
            style: const TextStyle(color: Colors.black),
            cursorColor: Colors.black,
            decoration: InputDecoration(
              hintText: '¿Qué quieres escuchar?',
              hintStyle: const TextStyle(color: Colors.black54),
              prefixIcon: const Icon(Icons.search_rounded, color: Colors.black87),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        Expanded(
          child: res.isEmpty
              ? const Center(
                  child: Text('Sin resultados',
                      style: TextStyle(color: Colors.white60)))
              : ListView.builder(
                  itemCount: res.length,
                  itemBuilder: (_, i) => SongTile(
                    song: res[i],
                    onTap: () => PlayerService.instance.playQueue(res, i),
                  ),
                ),
        ),
      ],
    );
  }
}

class _DownloadsTab extends StatelessWidget {
  const _DownloadsTab();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Downloads.instance,
      builder: (context, _) {
        final list = Downloads.instance.songs;
        return ListView(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Text('Descargas',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
            ),
            if (list.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Aún no has descargado nada. Toca la flecha ⬇ junto a una canción para escucharla sin internet.',
                  style: TextStyle(color: Colors.white60),
                ),
              ),
            for (var i = 0; i < list.length; i++)
              SongTile(
                song: list[i],
                onTap: () => PlayerService.instance.playQueue(list, i),
              ),
          ],
        );
      },
    );
  }
}
