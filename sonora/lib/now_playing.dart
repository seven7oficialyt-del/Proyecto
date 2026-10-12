import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import 'services.dart';
import 'theme.dart';
import 'widgets.dart';

class NowPlayingScreen extends StatelessWidget {
  const NowPlayingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ps = PlayerService.instance;
    final p = ps.player;
    final size = MediaQuery.of(context).size;
    final cover = (size.width - 56).clamp(0.0, size.height * 0.4).toDouble();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF4C3A8F), kBg],
            stops: [0, 0.75],
          ),
        ),
        child: SafeArea(
          child: ValueListenableBuilder<Song?>(
            valueListenable: ps.current,
            builder: (context, song, _) {
              if (song == null) return const SizedBox.shrink();
              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.keyboard_arrow_down_rounded,
                              size: 32),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const Expanded(
                          child: Text('Reproduciendo',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontWeight: FontWeight.w600)),
                        ),
                        const SizedBox(width: 48),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      decoration: const BoxDecoration(boxShadow: [
                        BoxShadow(color: Colors.black54, blurRadius: 30),
                      ]),
                      child: Cover(song.coverUrl, size: cover, radius: 12),
                    ),
                    const SizedBox(height: 28),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(song.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w800)),
                              const SizedBox(height: 4),
                              Text(song.artist,
                                  style: const TextStyle(
                                      color: Colors.white70, fontSize: 16)),
                            ],
                          ),
                        ),
                        DownloadButton(song: song),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const SeekBar(),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        StreamBuilder<bool>(
                          stream: p.shuffleModeEnabledStream,
                          builder: (_, s) {
                            final on = s.data ?? false;
                            return IconButton(
                              icon: Icon(Icons.shuffle_rounded,
                                  color: on ? kAccent : Colors.white70),
                              onPressed: () async {
                                if (!on) await p.shuffle();
                                await p.setShuffleModeEnabled(!on);
                              },
                            );
                          },
                        ),
                        IconButton(
                          iconSize: 40,
                          icon: const Icon(Icons.skip_previous_rounded),
                          onPressed: () => p.seekToPrevious(),
                        ),
                        const PlayPauseButton(size: 68),
                        IconButton(
                          iconSize: 40,
                          icon: const Icon(Icons.skip_next_rounded),
                          onPressed: () => p.seekToNext(),
                        ),
                        StreamBuilder<LoopMode>(
                          stream: p.loopModeStream,
                          builder: (_, s) {
                            final m = s.data ?? LoopMode.off;
                            return IconButton(
                              icon: Icon(
                                m == LoopMode.one
                                    ? Icons.repeat_one_rounded
                                    : Icons.repeat_rounded,
                                color: m == LoopMode.off
                                    ? Colors.white70
                                    : kAccent,
                              ),
                              onPressed: () => p.setLoopMode(
                                m == LoopMode.off
                                    ? LoopMode.all
                                    : m == LoopMode.all
                                        ? LoopMode.one
                                        : LoopMode.off,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class SeekBar extends StatefulWidget {
  const SeekBar({super.key});

  @override
  State<SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends State<SeekBar> {
  double? _drag;

  @override
  Widget build(BuildContext context) {
    final p = PlayerService.instance.player;
    return StreamBuilder<Duration>(
      stream: p.positionStream,
      builder: (context, snap) {
        final pos = snap.data ?? Duration.zero;
        final dur = p.duration ?? Duration.zero;
        final maxV = dur.inMilliseconds > 0 ? dur.inMilliseconds.toDouble() : 1.0;
        final val =
            _drag ?? pos.inMilliseconds.toDouble().clamp(0.0, maxV).toDouble();
        return Column(
          children: [
            Slider(
              value: val,
              max: maxV,
              onChanged: (v) => setState(() => _drag = v),
              onChangeEnd: (v) {
                p.seek(Duration(milliseconds: v.round()));
                setState(() => _drag = null);
              },
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(fmt(Duration(milliseconds: val.round())),
                      style: const TextStyle(
                          color: Colors.white60, fontSize: 12)),
                  Text(fmt(dur),
                      style: const TextStyle(
                          color: Colors.white60, fontSize: 12)),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
