import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import 'services.dart';
import 'theme.dart';

String fmt(Duration d) {
  final s = d.inSeconds % 60;
  return '${d.inMinutes}:${s.toString().padLeft(2, '0')}';
}

class Cover extends StatelessWidget {
  final String url;
  final double size;
  final double radius;
  const Cover(this.url, {super.key, this.size = 52, this.radius = 6});

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [kViolet, kAccent],
        ),
      ),
      child: Icon(Icons.music_note_rounded,
          color: Colors.white, size: size * 0.45),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: size,
        height: size,
        child: url.isEmpty
            ? placeholder
            : CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                placeholder: (_, __) => placeholder,
                errorWidget: (_, __, ___) => placeholder,
              ),
      ),
    );
  }
}

class PlayPauseButton extends StatelessWidget {
  final double size;
  const PlayPauseButton({super.key, this.size = 40});

  @override
  Widget build(BuildContext context) {
    final p = PlayerService.instance.player;
    return StreamBuilder<PlayerState>(
      stream: p.playerStateStream,
      builder: (context, snap) {
        final st = snap.data;
        final playing = st?.playing ?? false;
        final busy = st != null &&
            (st.processingState == ProcessingState.loading ||
                st.processingState == ProcessingState.buffering);
        return Container(
          width: size,
          height: size,
          decoration:
              const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
          child: (busy && playing)
              ? Padding(
                  padding: EdgeInsets.all(size * 0.25),
                  child: const CircularProgressIndicator(
                      strokeWidth: 2.5, color: Colors.black),
                )
              : IconButton(
                  padding: EdgeInsets.zero,
                  icon: Icon(
                    playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: Colors.black,
                    size: size * 0.65,
                  ),
                  onPressed: () => playing ? p.pause() : p.play(),
                ),
        );
      },
    );
  }
}

class DownloadButton extends StatelessWidget {
  final Song song;
  const DownloadButton({super.key, required this.song});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Downloads.instance,
      builder: (context, _) {
        final d = Downloads.instance;
        if (d.progress.containsKey(song.id)) {
          return SizedBox(
            width: 48,
            height: 48,
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, value: d.progress[song.id]),
              ),
            ),
          );
        }
        final messenger = ScaffoldMessenger.of(context);
        if (d.isDownloaded(song.id)) {
          return IconButton(
            tooltip: 'Quitar de descargas',
            icon: const Icon(Icons.download_done_rounded, color: kAccent),
            onPressed: () async {
              await d.remove(song);
              messenger.showSnackBar(
                  const SnackBar(content: Text('Quitada de descargas')));
            },
          );
        }
        return IconButton(
          tooltip: 'Descargar',
          icon: const Icon(Icons.arrow_circle_down_rounded,
              color: Colors.white60),
          onPressed: () async {
            try {
              await d.download(song);
            } catch (_) {
              messenger.showSnackBar(
                  const SnackBar(content: Text('No se pudo descargar')));
            }
          },
        );
      },
    );
  }
}

class SongTile extends StatelessWidget {
  final Song song;
  final VoidCallback onTap;
  const SongTile({super.key, required this.song, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Song?>(
      valueListenable: PlayerService.instance.current,
      builder: (context, cur, _) {
        final active = cur?.id == song.id;
        return ListTile(
          onTap: onTap,
          leading: Cover(song.coverUrl),
          title: Text(
            song.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: active ? kAccent : Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            song.artist,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white60),
          ),
          trailing: DownloadButton(song: song),
        );
      },
    );
  }
}

class MiniPlayer extends StatelessWidget {
  final VoidCallback onTap;
  const MiniPlayer({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final ps = PlayerService.instance;
    return ValueListenableBuilder<Song?>(
      valueListenable: ps.current,
      builder: (context, song, _) {
        if (song == null) return const SizedBox.shrink();
        return GestureDetector(
          onTap: onTap,
          child: Container(
            margin: const EdgeInsets.fromLTRB(8, 0, 8, 6),
            decoration: BoxDecoration(
              color: const Color(0xFF2B2346),
              borderRadius: BorderRadius.circular(10),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
                  child: Row(
                    children: [
                      Cover(song.coverUrl, size: 44, radius: 6),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(song.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            Text(song.artist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: Colors.white60, fontSize: 12)),
                          ],
                        ),
                      ),
                      const PlayPauseButton(size: 38),
                      IconButton(
                        icon: const Icon(Icons.skip_next_rounded),
                        onPressed: () => ps.player.seekToNext(),
                      ),
                    ],
                  ),
                ),
                StreamBuilder<Duration>(
                  stream: ps.player.positionStream,
                  builder: (context, snap) {
                    final pos = snap.data?.inMilliseconds ?? 0;
                    final dur = ps.player.duration?.inMilliseconds ?? 0;
                    return LinearProgressIndicator(
                      value: dur > 0 ? (pos / dur).clamp(0.0, 1.0) : 0,
                      minHeight: 2,
                      backgroundColor: Colors.white12,
                      color: Colors.white,
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
