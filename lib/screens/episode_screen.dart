import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/history_service.dart';
import '../services/cast_service.dart';

const _cyan = Color(0xFF00d4d4);
const _bg2 = Color(0xFF0f1117);
const _bg3 = Color(0xFF151720);
const _border = Color(0xFF1e2130);
const _textDim = Color(0xFF94a3b8);
const _red = Color(0xFFd44000);

class EpisodeScreen extends StatefulWidget {
  final AnimeResult anime;
  final AnilistMedia? anilistMedia;
  final double? autoPlay;
  final Duration? autoPlayResume;
  const EpisodeScreen({super.key, required this.anime, this.anilistMedia, this.autoPlay, this.autoPlayResume});

  @override
  State<EpisodeScreen> createState() => _EpisodeScreenState();
}

class _EpisodeScreenState extends State<EpisodeScreen> with WidgetsBindingObserver {
  List<double> _episodes = [];
  List<double> _filtered = [];
  bool _loading = true;
  String? _error;
  String _lang = 'sub';
  double? _playingEp;
  bool _loadingStream = false;
  final _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ScrollController _panelScrollController = ScrollController();

  late final Player _player;
  late final VideoController _videoController;
  bool _playerReady = false;

  // Overlay controls
  bool _showOverlay = false;
  Timer? _overlayTimer;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isPlaying = false;
  double _volume = 100;
  double _playbackSpeed = 1.0;
  bool _isFullscreen = false;
  bool _showCursor = true;
  bool _showEpisodePanel = false;
  StreamSubscription? _posSub;
  StreamSubscription? _durSub;
  StreamSubscription? _playSub;
  StreamSubscription? _completeSub;

  // Next episode
  bool _showNextEpPrompt = false;
  bool _cancelledNextEp = false;
  int _nextEpCountdown = 5;
  Timer? _nextEpTimer;

  // Skip times
  Map<String, dynamic>? _skipTimes;
  bool _showSkipIntro = false;
  bool _showSkipOutro = false;

  // Progress
  Timer? _progressTimer;
  Duration _lastSavedPosition = Duration.zero;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _player = Player();
    _videoController = VideoController(_player);
    _setupPlayerListeners();
    _loadEpisodes();
    _searchController.addListener(_filterEpisodes);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Listen to cast service for position updates when casting
    context.read<CastService>().addListener(_onCastUpdate);
  }

  void _onCastUpdate() {
    if (!mounted) return;
    final cast = context.read<CastService>();
    if (cast.isConnected) {
      _checkNextEpTiming(cast.castPosition);
    }
  }

  void _setupPlayerListeners() {
    _posSub = _player.stream.position.listen((pos) {
      if (mounted) {
        setState(() => _position = pos);
        _checkSkipTimes(pos);
        _checkNextEpTiming(pos);
      }
    });
    _durSub = _player.stream.duration.listen((dur) {
      if (mounted) setState(() => _duration = dur);
    });
    _playSub = _player.stream.playing.listen((playing) {
      if (mounted) setState(() => _isPlaying = playing);
    });
    _completeSub = _player.stream.completed.listen((completed) {
      if (completed && mounted) {
        if (_cancelledNextEp) setState(() => _cancelledNextEp = false);
        _onEpisodeComplete();
      }
    });
  }

  void _onEpisodeComplete() {
    if (_showNextEpPrompt || _playingEp == null || _cancelledNextEp) return;
    final idx = _episodes.indexOf(_playingEp!);
    if (idx < 0 || idx >= _episodes.length - 1) return;
    final nextEp = _episodes[idx + 1];
    setState(() { _showNextEpPrompt = true; _nextEpCountdown = 5; });
    _nextEpTimer?.cancel();
    _nextEpTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _nextEpCountdown--);
      if (_nextEpCountdown <= 0) {
        t.cancel();
        setState(() => _showNextEpPrompt = false);
        _playEpisode(nextEp);
      }
    });
  }

  void _checkSkipTimes(Duration pos) {
    if (_skipTimes == null) return;
    final secs = pos.inSeconds.toDouble();

    final op = _skipTimes!['op'] as Map<String, dynamic>?;
    final ed = _skipTimes!['ed'] as Map<String, dynamic>?;

    final inIntro = op != null && secs >= (op['start'] as double) && secs <= (op['end'] as double);
    final inOutro = ed != null && secs >= (ed['start'] as double) && secs <= (ed['end'] as double);

    if (_showSkipIntro != inIntro || _showSkipOutro != inOutro) {
      setState(() {
        _showSkipIntro = inIntro;
        _showSkipOutro = inOutro;
      });
    }
  }

  void _checkNextEpTiming(Duration pos) {
    if (_showNextEpPrompt || _playingEp == null || _cancelledNextEp) return;
    final cast = context.read<CastService>();
    // Use cast duration/position when casting
    final dur = cast.isConnected ? cast.castDuration : _duration;
    final currentPos = cast.isConnected ? cast.castPosition : pos;
    if (dur.inSeconds <= 0) return;
    final remaining = dur.inSeconds - currentPos.inSeconds;
    // Show next episode prompt 30 seconds before end
    if (remaining > 0 && remaining <= 30) {
      final idx = _episodes.indexOf(_playingEp!);
      if (idx >= 0 && idx < _episodes.length - 1) {
        _onEpisodeComplete();
      }
    }
  }

  Future<void> _fetchSkipTimes(double ep) async {
    final malId = widget.anilistMedia?.idMal;
    if (malId == null) return;
    try {
      final api = context.read<ApiService>();
      final times = await api.fetchSkipTimes(malId, ep.toInt());
        if (mounted) setState(() => _skipTimes = times);
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _player.pause();
      _saveCurrentProgress();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    context.read<CastService>().removeListener(_onCastUpdate);
    _progressTimer?.cancel();
    _overlayTimer?.cancel();
    _nextEpTimer?.cancel();
    _posSub?.cancel();
    _durSub?.cancel();
    _playSub?.cancel();
    _completeSub?.cancel();
    _saveCurrentProgress();
    _player.pause();
    _player.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    _panelScrollController.dispose();
    super.dispose();
  }

  void _startProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(seconds: 5), (_) => _saveCurrentProgress());
  }

  Future<void> _saveCurrentProgress() async {
    if (_playingEp == null || !mounted) return;
    final pos = _player.state.position;
    if (pos == _lastSavedPosition || pos.inSeconds < 3) return;
    _lastSavedPosition = pos;
    final history = context.read<HistoryService>();
    await history.save(widget.anime.id, widget.anime.name, widget.anime.provider, _playingEp!, _lang, progress: pos);
  }

  void _toggleOverlay() {
    setState(() { _showOverlay = !_showOverlay; _showCursor = _showOverlay; });
    if (_showOverlay) {
      _overlayTimer?.cancel();
      _overlayTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() { _showOverlay = false; _showCursor = false; });
      });
    }
  }

  void _keepOverlay() {
    setState(() { _showCursor = true; });
    _overlayTimer?.cancel();
    _overlayTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() { _showOverlay = false; _showCursor = false; });
    });
  }

  void _onMouseMove() {
    if (!_showOverlay) setState(() { _showOverlay = true; _showCursor = true; });
    _keepOverlay();
  }

  Future<void> _toggleFullscreen() async {
    _isFullscreen = !_isFullscreen;
    if (_isFullscreen) {
      await windowManager.setFullScreen(true);
    } else {
      await windowManager.setFullScreen(false);
    }
    setState(() {});
    _keepOverlay();
  }

  Future<void> _loadEpisodes() async {
    setState(() { _loading = true; _error = null; });
    try {
      final api = context.read<ApiService>();
      final eps = await api.getEpisodes(widget.anime.id, widget.anime.provider, _lang);
      setState(() { _episodes = eps; _filtered = eps; _loading = false; });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (widget.autoPlay != null) {
          final ep = _episodes.firstWhere(
            (e) => e == widget.autoPlay || e.toInt() == widget.autoPlay!.toInt(),
            orElse: () => _episodes.first,
          );
          _playEpisode(ep, resumeFrom: widget.autoPlayResume);
        } else {
          _checkAutoResume();
        }
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  void _filterEpisodes() {
    final q = _searchController.text.trim();
    setState(() {
      if (q.isEmpty) {
        _filtered = _episodes;
      } else {
        final n = double.tryParse(q);
        _filtered = _episodes.where((ep) {
          if (n != null) return ep == n || ep.toInt() == n.toInt();
          return ep.toString().contains(q);
        }).toList();
      }
    });
  }

  void _checkAutoResume() {
    final history = context.read<HistoryService>();
    final saved = history.getEntry(widget.anime.id);
    if (saved == null) return;

    final hasProgress = saved.progress != null && saved.progress!.inSeconds > 5;
    // Only suggest next episode if watched past 85% (~20min of 24min episode)
    final nearComplete = saved.progress != null && saved.progress!.inSeconds > (24 * 60 * 0.85);

    final nextIdx = _episodes.indexWhere((e) => e > saved.episode);
    final nextEp = (nearComplete && nextIdx >= 0) ? _episodes[nextIdx] : null;
    final resumeEp = nextEp ?? saved.episode;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _bg2,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: Text(
          nextEp != null ? 'CONTINUE TO EP ${resumeEp.toInt()}?' : 'RESUME EP ${resumeEp.toInt()}?',
          style: const TextStyle(fontFamily: 'monospace', fontSize: 13, color: _cyan, letterSpacing: 1),
        ),
        content: Text(
          nextEp != null ? 'Last watched EP ${saved.episode.toInt()}. Play next?'
              : hasProgress ? 'Resume from ${_fmt(saved.progress!)}?' : 'Resume from beginning?',
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: _textDim),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
            child: const Text('BROWSE', style: TextStyle(fontFamily: 'monospace', color: _textDim))),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _playEpisode(resumeEp, resumeFrom: nextEp == null && hasProgress ? saved.progress : null);
            },
            child: const Text('PLAY', style: TextStyle(fontFamily: 'monospace', color: _cyan))),
        ],
      ),
    );
  }

  void _jumpToNextUnwatched() {
    final history = context.read<HistoryService>();
    final saved = history.getEntry(widget.anime.id);
    final lastEp = saved?.episode ?? 0;
    final nextUnwatched = _episodes.firstWhere((e) => e > lastEp, orElse: () => _episodes.first);
    _playEpisode(nextUnwatched);
  }

  void _preCacheNextEpisode(double currentEp) {
    final idx = _episodes.indexOf(currentEp);
    if (idx < 0 || idx >= _episodes.length - 1) return;
    final nextEp = _episodes[idx + 1];
    // Fire and forget — just warm up the server cache
    final api = context.read<ApiService>();
    api.getStreamUrl(widget.anime.id, nextEp, widget.anime.provider, _lang)
        .catchError((_) => '');
  }

  void _showSpeedPicker() {
    const speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0d0f18),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: const Text('PLAYBACK SPEED', style: TextStyle(fontFamily: 'monospace', fontSize: 12, color: _cyan, letterSpacing: 2)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: speeds.map((s) {
            final active = s == _playbackSpeed;
            return GestureDetector(
              onTap: () {
                setState(() => _playbackSpeed = s);
                _player.setRate(s);
                Navigator.pop(context);
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                margin: const EdgeInsets.only(bottom: 4),
                decoration: BoxDecoration(
                  color: active ? _cyan.withOpacity(0.15) : Colors.transparent,
                  border: Border.all(color: active ? _cyan.withOpacity(0.4) : _border),
                ),
                child: Text(
                  s == s.truncateToDouble() ? '${s.toInt()}x' : '${s}x',
                  style: TextStyle(fontFamily: 'monospace', fontSize: 13, color: active ? _cyan : _textDim),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showCastDialog() async {
    final cast = context.read<CastService>();

    // If already casting, show episode switcher instead of device picker
    if (cast.isConnected) {
      _showCastEpisodeDialog();
      return;
    }

    await cast.startScan();
    if (!mounted) return;
    final manualController = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => Consumer<CastService>(
        builder: (context, cast, _) => AlertDialog(
          backgroundColor: _bg2,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          title: Row(children: [
            const Text('CAST TO DEVICE', style: TextStyle(fontFamily: 'monospace', fontSize: 13, color: _cyan, letterSpacing: 1)),
            const Spacer(),
            if (cast.scanning) const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: _cyan, strokeWidth: 2)),
          ]),
          content: SizedBox(
            width: 300,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (cast.devices.isEmpty && !cast.scanning)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: Text('NO DEVICES FOUND AUTOMATICALLY',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: _textDim)),
                  ),
                ...cast.devices.map((d) => ListTile(
                  leading: Icon(Icons.cast, color: cast.connectedDevice == d ? _cyan : _textDim),
                  title: Text(d.name, style: TextStyle(
                    fontFamily: 'monospace', fontSize: 12,
                    color: cast.connectedDevice == d ? _cyan : const Color(0xFFc8ccd8),
                  )),
                  subtitle: Text(d.host, style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: _textDim)),
                  onTap: () async {
                    await cast.connect(d);
                    if (_playingEp != null && mounted) {
                      final api = context.read<ApiService>();
                      final url = api.getProxyUrl(widget.anime.id, _playingEp!, widget.anime.provider, _lang);
                      await cast.cast(url, '${widget.anime.name} EP ${_playingEp!.toInt()}');
                      _player.pause();
                      await _player.stop();
                    }
                    if (mounted) Navigator.pop(context);
                  },
                )),
                const Divider(color: _border),
                const Text('ENTER IP MANUALLY', style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: _textDim, letterSpacing: 2)),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: manualController,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Color(0xFFc8ccd8)),
                      decoration: InputDecoration(
                        hintText: '192.168.x.x',
                        hintStyle: const TextStyle(fontFamily: 'monospace', color: _textDim, fontSize: 12),
                        filled: true, fillColor: _bg3, isDense: true,
                        border: OutlineInputBorder(borderSide: const BorderSide(color: _border), borderRadius: BorderRadius.zero),
                        enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: _border), borderRadius: BorderRadius.zero),
                        focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: _cyan), borderRadius: BorderRadius.zero),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () async {
                      final ip = manualController.text.trim();
                      if (ip.isEmpty) return;
                      final device = ChromecastDevice(name: 'Chromecast ($ip)', host: ip, port: 8009);
                      await cast.connect(device);
                      if (_playingEp != null && mounted) {
                        final api = context.read<ApiService>();
                        final url = api.getProxyUrl(widget.anime.id, _playingEp!, widget.anime.provider, _lang);
                        await cast.cast(url, '${widget.anime.name} EP ${_playingEp!.toInt()}');
                        _player.pause();
                        await _player.stop();
                      }
                      if (mounted) Navigator.pop(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(border: Border.all(color: _cyan.withOpacity(0.5))),
                      child: const Text('CONNECT', style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: _cyan)),
                    ),
                  ),
                ]),
              ],
            ),
          ),
          actions: [
            if (cast.isConnected)
              TextButton(
                onPressed: () { cast.disconnect(); Navigator.pop(context); },
                child: const Text('DISCONNECT', style: TextStyle(fontFamily: 'monospace', color: _red)),
              ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CLOSE', style: TextStyle(fontFamily: 'monospace', color: _textDim)),
            ),
          ],
        ),
      ),
    );
  }

  void _showCastEpisodeDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _bg2,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: const Text('CAST — SELECT EPISODE', style: TextStyle(fontFamily: 'monospace', fontSize: 13, color: _cyan, letterSpacing: 1)),
        content: SizedBox(
          width: 300,
          height: 400,
          child: ListView.builder(
            itemCount: _episodes.length,
            itemExtent: 48,
            itemBuilder: (context, i) {
              final ep = _episodes[i];
              final isCurrent = ep == _playingEp;
              return ListTile(
                dense: true,
                leading: Text(ep.toInt().toString().padLeft(2, '0'),
                  style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: isCurrent ? _cyan : _textDim)),
                title: Text('Episode ${ep.toInt()}', style: TextStyle(
                  fontFamily: 'monospace', fontSize: 12,
                  color: isCurrent ? _cyan : const Color(0xFFc8ccd8),
                )),
                trailing: isCurrent ? const Text('NOW CASTING', style: TextStyle(fontFamily: 'monospace', fontSize: 9, color: _cyan)) : null,
                onTap: () {
                  Navigator.pop(context);
                  _playEpisode(ep);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              context.read<CastService>().disconnect();
              Navigator.pop(context);
            },
            child: const Text('DISCONNECT', style: TextStyle(fontFamily: 'monospace', color: _red)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CLOSE', style: TextStyle(fontFamily: 'monospace', color: _textDim)),
          ),
        ],
      ),
    );
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '${d.inHours > 0 ? '${d.inHours}:' : ''}$m:$s';
  }

  Future<void> _playEpisode(double ep, {Duration? resumeFrom}) async {
    setState(() { _loadingStream = true; _playingEp = ep; _playerReady = false; _showNextEpPrompt = false; _cancelledNextEp = false; _showSkipIntro = false; _showSkipOutro = false; _skipTimes = null; });
    _progressTimer?.cancel();
    _nextEpTimer?.cancel();
    _lastSavedPosition = Duration.zero;
    _fetchSkipTimes(ep);
    final api = context.read<ApiService>();
    final cast = context.read<CastService>();
    final history = context.read<HistoryService>();
    final proxyUrl = api.getProxyUrl(widget.anime.id, ep, widget.anime.provider, _lang);
    final title = '${widget.anime.name} EP ${ep.toInt()}';

    try {
      // If casting, send to Chromecast instead of local player
      if (cast.isConnected) {
        await cast.cast(proxyUrl, title);
        await history.save(widget.anime.id, widget.anime.name, widget.anime.provider, ep, _lang);
        // Stop local playback completely
        _player.pause();
        await _player.stop();
        if (mounted) setState(() { _loadingStream = false; _playerReady = false; });
        _scrollToEpisode(ep);
        return;
      }

      // Local playback
      await _player.open(Media(proxyUrl));
      if (resumeFrom != null && resumeFrom.inSeconds > 3) {
        await Future.delayed(const Duration(milliseconds: 1500));
        if (mounted) await _player.seek(resumeFrom);
      }
      await history.save(widget.anime.id, widget.anime.name, widget.anime.provider, ep, _lang);
      if (mounted) setState(() { _loadingStream = false; _playerReady = true; });
      _startProgressTimer();
      // Pre-cache next episode URL in background
      _preCacheNextEpisode(ep);
      _scrollToEpisode(ep);
    } catch (e) {
      if (mounted) {
        setState(() { _loadingStream = false; });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _scrollToEpisode(double ep) {
    final idx = _filtered.indexOf(ep);
    if (idx < 0 || !_scrollController.hasClients) return;
    final offset = (idx * 49.0).clamp(0.0, _scrollController.position.maxScrollExtent);
    _scrollController.animateTo(offset, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
  }

  void _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    switch (event.logicalKey) {
      case LogicalKeyboardKey.space:
        _isPlaying ? _player.pause() : _player.play();
        _toggleOverlay();
        break;
      case LogicalKeyboardKey.arrowRight:
        _player.seek(_position + const Duration(seconds: 10));
        _keepOverlay();
        break;
      case LogicalKeyboardKey.arrowLeft:
        _player.seek(_position - const Duration(seconds: 10));
        _keepOverlay();
        break;
      case LogicalKeyboardKey.arrowUp:
        setState(() => _volume = (_volume + 10).clamp(0, 100));
        _player.setVolume(_volume);
        _keepOverlay();
        break;
      case LogicalKeyboardKey.arrowDown:
        setState(() => _volume = (_volume - 10).clamp(0, 100));
        _player.setVolume(_volume);
        _keepOverlay();
        break;
      case LogicalKeyboardKey.keyF:
        _toggleFullscreen();
        break;
      case LogicalKeyboardKey.escape:
        if (_isFullscreen) _toggleFullscreen();
        break;
      case LogicalKeyboardKey.keyM:
        setState(() => _volume = _volume > 0 ? 0 : 100);
        _player.setVolume(_volume);
        _keepOverlay();
        break;
      case LogicalKeyboardKey.question:
        _showShortcutsOverlay();
        break;
    }
  }

  void _showShortcutsOverlay() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0d0f18),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: const Text('KEYBOARD SHORTCUTS', style: TextStyle(
          fontFamily: 'monospace', fontSize: 12, color: _cyan, letterSpacing: 2,
        )),
        content: const SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ShortcutRow('Space', 'Play / Pause'),
              _ShortcutRow('→', 'Skip forward 10s'),
              _ShortcutRow('←', 'Skip back 10s'),
              _ShortcutRow('↑', 'Volume up'),
              _ShortcutRow('↓', 'Volume down'),
              _ShortcutRow('M', 'Mute / Unmute'),
              _ShortcutRow('F', 'Toggle fullscreen'),
              _ShortcutRow('Esc', 'Exit fullscreen'),
              _ShortcutRow('?', 'Show this overlay'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CLOSE', style: TextStyle(fontFamily: 'monospace', color: _textDim)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final history = context.watch<HistoryService>();
    final cast = context.watch<CastService>();
    final saved = history.getEntry(widget.anime.id);
    final lastEp = saved?.episode;
    final screenH = MediaQuery.of(context).size.height;

    // Use cast position/duration when casting, local player otherwise
    final displayPosition = cast.isConnected ? cast.castPosition : _position;
    final displayDuration = cast.isConnected ? cast.castDuration : _duration;

    return KeyboardListener(
      focusNode: FocusNode()..requestFocus(),
      onKeyEvent: _handleKey,
      child: PopScope(
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) {
            if (_isFullscreen) windowManager.setFullScreen(false);
            _progressTimer?.cancel();
            _saveCurrentProgress();
            _player.pause();
          }
        },
        child: Scaffold(
          backgroundColor: const Color(0xFF0a0b0f),
          appBar: _isFullscreen ? null : AppBar(
            title: Text(widget.anime.name, style: const TextStyle(fontFamily: 'monospace', fontSize: 13, color: _cyan), overflow: TextOverflow.ellipsis),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: _textDim),
              onPressed: () { _progressTimer?.cancel(); _saveCurrentProgress(); _player.pause(); Navigator.pop(context); },
            ),
          ),
          body: _isFullscreen
              ? Stack(
                  children: [
                    Container(
                      color: Colors.black,
                      child: MouseRegion(
                        cursor: _showCursor ? SystemMouseCursors.basic : SystemMouseCursors.none,
                        onHover: (_) => _onMouseMove(),
                        child: GestureDetector(
                          onTap: _toggleOverlay,
                          child: Video(controller: _videoController, controls: NoVideoControls),
                        ),
                      ),
                    ),
                    if (_showOverlay)
                      _PlayerOverlay(
                        position: displayPosition,
                        duration: displayDuration,
                        isPlaying: _isPlaying,
                        volume: _volume,
                        onPlayPause: () { _isPlaying ? _player.pause() : _player.play(); _keepOverlay(); },
                        onSeek: (v) {
                          // Only update local UI while dragging
                          setState(() => _position = Duration(seconds: (v * displayDuration.inSeconds).round()));
                          _keepOverlay();
                        },
                        onSeekEnd: (v) {
                          // Actually seek when drag ends
                          final pos = Duration(seconds: (v * displayDuration.inSeconds).round());
                          if (cast.isConnected) { cast.seek(pos); } else { _player.seek(pos); }
                          _keepOverlay();
                        },
                        onVolume: (v) { setState(() => _volume = v); _player.setVolume(v); _keepOverlay(); },
                        onSkipBack: () {
                          final pos = displayPosition - const Duration(seconds: 10);
                          if (cast.isConnected) { cast.seek(pos); } else { _player.seek(pos); }
                          _keepOverlay();
                        },
                        onSkipForward: () {
                          final pos = displayPosition + const Duration(seconds: 10);
                          if (cast.isConnected) { cast.seek(pos); } else { _player.seek(pos); }
                          _keepOverlay();
                        },
                        onCast: _showCastDialog,
                        isCasting: cast.isConnected,
                        onFullscreen: _toggleFullscreen,
                        isFullscreen: _isFullscreen,
                        onNextEpisode: _playingEp != null && _episodes.indexOf(_playingEp!) < _episodes.length - 1
                            ? () { final idx = _episodes.indexOf(_playingEp!); if (idx >= 0 && idx < _episodes.length - 1) _playEpisode(_episodes[idx + 1]); }
                            : null,
                        speed: _playbackSpeed,
                        onSpeed: _showSpeedPicker,
                        onEpisodes: () => setState(() => _showEpisodePanel = !_showEpisodePanel),
                        title: widget.anime.name,
                        episode: _playingEp,
                      ),
                    if (_showNextEpPrompt)
                      _NextEpPrompt(
                        countdown: _nextEpCountdown,
                        onPlay: () {
                          _nextEpTimer?.cancel();
                          setState(() => _showNextEpPrompt = false);
                          final idx = _episodes.indexOf(_playingEp!);
                          if (idx >= 0 && idx < _episodes.length - 1) _playEpisode(_episodes[idx + 1]);
                        },
                        onCancel: () { _nextEpTimer?.cancel(); setState(() { _showNextEpPrompt = false; _cancelledNextEp = true; }); },
                      ),
                    if (_showSkipIntro)
                      _SkipButton(label: 'SKIP INTRO', onTap: () {
                        final end = (_skipTimes!['op']['end'] as double);
                        _player.seek(Duration(seconds: end.toInt()));
                      }),
                    if (_showSkipOutro)
                      _SkipButton(label: 'SKIP OUTRO', onTap: () {
                        final idx = _episodes.indexOf(_playingEp!);
                        if (idx >= 0 && idx < _episodes.length - 1) _playEpisode(_episodes[idx + 1]);
                      }),
                  ],
                )
              : Stack(
            children: [
              Column(
            children: [
              // Video player with overlay
              if (_playingEp != null)
                Expanded(
                  child: Stack(
                    children: [
                      Container(
                        color: Colors.black,
                        child: _loadingStream
                            ? const Center(child: CircularProgressIndicator(color: _cyan))
                            : MouseRegion(
                                cursor: _showCursor ? SystemMouseCursors.basic : SystemMouseCursors.none,
                                onHover: (_) => _onMouseMove(),
                                child: GestureDetector(
                                  onTap: _toggleOverlay,
                                  child: Video(
                                    controller: _videoController,
                                  controls: NoVideoControls,
                                ),
                              ),
                              ),
                      ),
                      // Controls overlay
                      if (_showOverlay && !_loadingStream)
                        _PlayerOverlay(
                          position: displayPosition,
                          duration: displayDuration,
                          isPlaying: _isPlaying,
                          volume: _volume,
                          onPlayPause: () { _isPlaying ? _player.pause() : _player.play(); _keepOverlay(); },
                          onSeek: (v) {
                            setState(() => _position = Duration(seconds: (v * displayDuration.inSeconds).round()));
                            _keepOverlay();
                          },
                          onSeekEnd: (v) {
                            final pos = Duration(seconds: (v * displayDuration.inSeconds).round());
                            if (cast.isConnected) { cast.seek(pos); } else { _player.seek(pos); }
                            _keepOverlay();
                          },
                          onVolume: (v) { setState(() => _volume = v); _player.setVolume(v); _keepOverlay(); },
                          onSkipBack: () {
                            final pos = displayPosition - const Duration(seconds: 10);
                            if (cast.isConnected) { cast.seek(pos); } else { _player.seek(pos); }
                            _keepOverlay();
                          },
                          onSkipForward: () {
                            final pos = displayPosition + const Duration(seconds: 10);
                            if (cast.isConnected) { cast.seek(pos); } else { _player.seek(pos); }
                            _keepOverlay();
                          },
                          onCast: _showCastDialog,
                          isCasting: cast.isConnected,
                          onFullscreen: _toggleFullscreen,
                          isFullscreen: _isFullscreen,
                          onNextEpisode: _playingEp != null && _episodes.indexOf(_playingEp!) < _episodes.length - 1
                              ? () { final idx = _episodes.indexOf(_playingEp!); if (idx >= 0 && idx < _episodes.length - 1) _playEpisode(_episodes[idx + 1]); }
                              : null,
                          speed: _playbackSpeed,
                        onSpeed: _showSpeedPicker,
                        onEpisodes: () => setState(() => _showEpisodePanel = !_showEpisodePanel),
                        title: widget.anime.name,
                        episode: _playingEp,
                        ),
                      // Next episode prompt
                      if (_showNextEpPrompt)
                        _NextEpPrompt(
                          countdown: _nextEpCountdown,
                          onPlay: () {
                            _nextEpTimer?.cancel();
                            setState(() => _showNextEpPrompt = false);
                            final idx = _episodes.indexOf(_playingEp!);
                            if (idx >= 0 && idx < _episodes.length - 1) _playEpisode(_episodes[idx + 1]);
                          },
                          onCancel: () { _nextEpTimer?.cancel(); setState(() { _showNextEpPrompt = false; _cancelledNextEp = true; }); },
                        ),
                      if (_showSkipIntro)
                        _SkipButton(label: 'SKIP INTRO', onTap: () {
                          final end = (_skipTimes!['op']['end'] as double);
                          _player.seek(Duration(seconds: end.toInt()));
                        }),
                      if (_showSkipOutro)
                        _SkipButton(label: 'SKIP OUTRO', onTap: () {
                          final idx = _episodes.indexOf(_playingEp!);
                          if (idx >= 0 && idx < _episodes.length - 1) _playEpisode(_episodes[idx + 1]);
                        }),
                    ],
                  ),
                ),
              if (_playingEp == null)
                Expanded(
                  child: Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.play_circle_outline, color: _textDim, size: 64),
                      const SizedBox(height: 16),
                      const Text('SELECT AN EPISODE', style: TextStyle(fontFamily: 'monospace', fontSize: 12, color: _textDim, letterSpacing: 3)),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () => setState(() => _showEpisodePanel = true),
                        child: Container(
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          decoration: BoxDecoration(
                            border: Border.all(color: _cyan.withOpacity(0.4)),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('EPISODES', style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: _cyan, letterSpacing: 2)),
                        ),
                      ),
                    ]),
                  ),
                ),

            ],
          ), // end Column (non-fullscreen)
          // Dimmed backdrop when panel open
          if (_showEpisodePanel)
            Positioned.fill(
              child: GestureDetector(
                onTap: () => setState(() => _showEpisodePanel = false),
                child: Container(color: Colors.black54),
              ),
            ),
          // Episode panel slides in from right
          AnimatedPositioned(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            right: _showEpisodePanel ? 0 : -320,
            top: 0, bottom: 0,
            width: 300,
            child: Container(
              color: const Color(0xFF0d0f18),
              child: Column(children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                  color: const Color(0xFF111827),
                  child: Row(children: [
                    Expanded(
                      child: Text(widget.anime.name, style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFe2e8f0),
                      ), overflow: TextOverflow.ellipsis),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: _textDim, size: 18),
                      onPressed: () => setState(() => _showEpisodePanel = false),
                    ),
                  ]),
                ),
                Container(
                  color: const Color(0xFF111827),
                  child: Row(children: [_langBtn('SUB', 'sub'), _langBtn('DUB', 'dub')]),
                ),
                const Divider(color: _border, height: 1),
                if (_episodes.length > 20)
                  Container(
                    color: const Color(0xFF111827),
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Color(0xFFc8ccd8)),
                      decoration: InputDecoration(
                        hintText: 'JUMP TO EPISODE...',
                        hintStyle: const TextStyle(fontFamily: 'monospace', color: _textDim, fontSize: 12),
                        filled: true, fillColor: const Color(0xFF0d0f18), isDense: true,
                        prefixIcon: const Icon(Icons.search, color: _textDim, size: 16),
                        border: OutlineInputBorder(borderSide: const BorderSide(color: _border), borderRadius: BorderRadius.zero),
                        enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: _border), borderRadius: BorderRadius.zero),
                        focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: _cyan), borderRadius: BorderRadius.zero),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                    ),
                  ),
                const Divider(color: _border, height: 1),
                Expanded(
                  child: ListView.builder(
                    controller: _panelScrollController,
                    itemCount: _filtered.length,
                    itemExtent: 49,
                    itemBuilder: (context, i) {
                      final ep = _filtered[i];
                      final isWatched = lastEp != null && ep < lastEp;
                      final isCurrent = lastEp != null && ep == lastEp;
                      final isPlaying = ep == _playingEp;
                      final progress = isCurrent ? saved?.progress : null;
                      return _EpisodeItem(
                        episode: ep,
                        isWatched: isWatched,
                        isCurrent: isCurrent,
                        isPlaying: isPlaying,
                        progress: progress,
                        onTap: () {
                          setState(() => _showEpisodePanel = false);
                          _playEpisode(ep, resumeFrom: isCurrent ? saved?.progress : null);
                        },
                      );
                    },
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
        ),
      ),
    );
  }

  Widget _langBtn(String label, String value) {
    final active = _lang == value;
    return Expanded(
      child: GestureDetector(
        onTap: () { setState(() => _lang = value); _loadEpisodes(); },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? _cyan.withOpacity(0.1) : Colors.transparent,
            border: Border(bottom: BorderSide(color: active ? _cyan : Colors.transparent, width: 2)),
          ),
          child: Text(label, textAlign: TextAlign.center, style: TextStyle(
            fontFamily: 'monospace', fontSize: 11, color: active ? _cyan : _textDim, letterSpacing: 2,
          )),
        ),
      ),
    );
  }
}

// --- PLAYER OVERLAY ---
class _PlayerOverlay extends StatelessWidget {
  final Duration position;
  final Duration duration;
  final bool isPlaying;
  final double volume;
  final VoidCallback onPlayPause;
  final ValueChanged<double> onSeek;
  final ValueChanged<double> onSeekEnd;
  final ValueChanged<double> onVolume;
  final VoidCallback onSkipBack;
  final VoidCallback onSkipForward;
  final VoidCallback onCast;
  final bool isCasting;
  final VoidCallback onFullscreen;
  final bool isFullscreen;
  final VoidCallback? onNextEpisode;
  final VoidCallback? onEpisodes;
  final VoidCallback? onSpeed;
  final double speed;
  final String? title;
  final double? episode;

  const _PlayerOverlay({
    required this.position,
    required this.duration,
    required this.isPlaying,
    required this.volume,
    required this.speed,
    required this.onPlayPause,
    required this.onSeek,
    required this.onSeekEnd,
    required this.onVolume,
    required this.onSkipBack,
    required this.onSkipForward,
    required this.onCast,
    required this.isCasting,
    required this.onFullscreen,
    required this.isFullscreen,
    this.onNextEpisode,
    this.onEpisodes,
    this.onSpeed,
    this.title,
    this.episode,
  });

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '${d.inHours > 0 ? '${d.inHours}:' : ''}$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final progress = duration.inSeconds > 0 ? position.inSeconds / duration.inSeconds : 0.0;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Episode label
          if (episode != null || title != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                episode != null && title != null
                    ? 'EP ${episode!.toInt()} — $title'
                    : episode != null ? 'EPISODE ${episode!.toInt()}' : title!,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.white60, letterSpacing: 1),
                textAlign: TextAlign.center,
              ),
            ),
          // Seek bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(children: [
              Text(_fmt(position), style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: Colors.white70)),
              Expanded(
                child: SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 2,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                    activeTrackColor: const Color(0xFF00d4d4),
                    inactiveTrackColor: Colors.white24,
                    thumbColor: const Color(0xFF00d4d4),
                    overlayColor: const Color(0xFF00d4d4).withOpacity(0.2),
                  ),
                  child: Slider(
                    value: progress.clamp(0.0, 1.0),
                    onChanged: onSeek,
                    onChangeEnd: onSeekEnd,
                  ),
                ),
              ),
              Text(_fmt(duration), style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: Colors.white70)),
            ]),
          ),
          // Controls row
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Row(children: [
              // Skip back
              IconButton(
                icon: const Icon(Icons.replay_10, color: Colors.white, size: 28),
                onPressed: onSkipBack,
              ),
              // Play/Pause
              IconButton(
                icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow, color: const Color(0xFF00d4d4), size: 36),
                onPressed: onPlayPause,
              ),
              // Skip forward
              IconButton(
                icon: const Icon(Icons.forward_10, color: Colors.white, size: 28),
                onPressed: onSkipForward,
              ),
              // Next episode
              if (onNextEpisode != null)
                IconButton(
                  icon: const Icon(Icons.skip_next, color: Colors.white, size: 28),
                  onPressed: onNextEpisode,
                  tooltip: 'Next episode',
                ),
              const Spacer(),
              // Speed button
              if (onSpeed != null)
                GestureDetector(
                  onTap: onSpeed,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: speed != 1.0
                          ? const Color(0xFF00d4d4).withOpacity(0.6)
                          : Colors.white24),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      speed == speed.truncateToDouble() ? '${speed.toInt()}x' : '${speed}x',
                      style: TextStyle(
                        fontFamily: 'monospace', fontSize: 11,
                        color: speed != 1.0 ? const Color(0xFF00d4d4) : Colors.white70,
                      ),
                    ),
                  ),
                ),
              // Episodes button
              if (onEpisodes != null)
                IconButton(
                  icon: const Icon(Icons.format_list_bulleted, color: Colors.white70, size: 20),
                  onPressed: onEpisodes,
                  tooltip: 'Episodes',
                ),
              // Cast button
              IconButton(
                icon: Icon(Icons.cast, color: isCasting ? const Color(0xFF00d4d4) : Colors.white54, size: 20),
                onPressed: onCast,
                tooltip: isCasting ? 'Casting' : 'Cast to device',
              ),
              // Volume
              const Icon(Icons.volume_up, color: Colors.white54, size: 16),
              SizedBox(
                width: 80,
                child: SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 2,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                    activeTrackColor: Colors.white70,
                    inactiveTrackColor: Colors.white24,
                    thumbColor: Colors.white,
                    overlayColor: Colors.white12,
                  ),
                  child: Slider(value: volume / 100, onChanged: (v) => onVolume(v * 100)),
                ),
              ),
              // Fullscreen button
              IconButton(
                icon: Icon(
                  isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
                  color: Colors.white70, size: 22,
                ),
                onPressed: onFullscreen,
                tooltip: isFullscreen ? 'Exit fullscreen (F)' : 'Fullscreen (F)',
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

// --- NEXT EPISODE PROMPT ---
class _NextEpPrompt extends StatelessWidget {
  final int countdown;
  final VoidCallback onPlay;
  final VoidCallback onCancel;

  const _NextEpPrompt({required this.countdown, required this.onPlay, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 80,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF0f1117).withOpacity(0.95),
          border: Border.all(color: const Color(0xFF00d4d4).withOpacity(0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('NEXT EPISODE IN', style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: Color(0xFF94a3b8), letterSpacing: 2)),
            Text('$countdown', style: const TextStyle(fontFamily: 'monospace', fontSize: 32, color: Color(0xFF00d4d4), height: 1)),
            const SizedBox(height: 10),
            Row(mainAxisSize: MainAxisSize.min, children: [
              GestureDetector(
                onTap: onCancel,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(border: Border.all(color: const Color(0xFF1e2130))),
                  child: const Text('CANCEL', style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: Color(0xFF94a3b8), letterSpacing: 1)),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onPlay,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(border: Border.all(color: const Color(0xFF00d4d4).withOpacity(0.5))),
                  child: const Text('PLAY NOW', style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: Color(0xFF00d4d4), letterSpacing: 1)),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

// --- EPISODE ITEM ---
class _EpisodeItem extends StatelessWidget {
  final double episode;
  final bool isWatched;
  final bool isCurrent;
  final bool isPlaying;
  final Duration? progress;
  final VoidCallback onTap;

  const _EpisodeItem({
    required this.episode, required this.isWatched, required this.isCurrent,
    required this.isPlaying, required this.onTap, this.progress,
  });

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '${d.inHours > 0 ? '${d.inHours}:' : ''}$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    const totalSecs = 24 * 60;
    final progressPct = (progress != null && progress!.inSeconds > 0)
        ? (progress!.inSeconds / totalSecs).clamp(0.0, 1.0) : null;

    return InkWell(
      onTap: onTap,
      child: Stack(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isPlaying ? _cyan.withOpacity(0.1) : isCurrent ? _cyan.withOpacity(0.05) : Colors.transparent,
            border: const Border(bottom: BorderSide(color: _border, width: 0.5)),
          ),
          child: Row(children: [
            SizedBox(width: 32,
              child: Text(episode.toInt().toString().padLeft(2, '0'), style: TextStyle(
                fontFamily: 'monospace', fontSize: 11,
                color: isPlaying ? _cyan : isCurrent ? _cyan : isWatched ? _cyan.withOpacity(0.4) : _textDim,
              ))),
            Text('Episode ${episode.toInt()}', style: TextStyle(
              fontFamily: 'monospace', fontSize: 13,
              color: isWatched ? _textDim.withOpacity(0.5) : const Color(0xFFc8ccd8),
            )),
            const Spacer(),
            if (isPlaying)
              const Text('▶ PLAYING', style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: _cyan, letterSpacing: 1))
            else if (isCurrent && progress != null && progress!.inSeconds > 5)
              Text(_fmt(progress!), style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: _cyan, letterSpacing: 1))
            else if (isCurrent)
              const Text('CONTINUE', style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: _cyan, letterSpacing: 1))
            else
              const Text('▶ PLAY', style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: _textDim, letterSpacing: 1)),
          ]),
        ),
        if (progressPct != null)
          Positioned(bottom: 0, left: 0, right: 0,
            child: LinearProgressIndicator(value: progressPct, minHeight: 2,
              backgroundColor: Colors.transparent,
              valueColor: const AlwaysStoppedAnimation<Color>(_cyan))),
      ]),
    );
  }
}

// --- SKIP BUTTON ---
class _SkipButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _SkipButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 80,
      left: 16,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF0f1117).withOpacity(0.95),
            border: Border.all(color: const Color(0xFF00d4d4).withOpacity(0.6)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.fast_forward, color: Color(0xFF00d4d4), size: 16),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(
              fontFamily: 'monospace', fontSize: 11,
              color: Color(0xFF00d4d4), letterSpacing: 2,
            )),
          ]),
        ),
      ),
    );
  }
}

class _ShortcutRow extends StatelessWidget {
  final String keyLabel;
  final String description;
  const _ShortcutRow(this.keyLabel, this.description);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        Container(
          width: 80,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF1e2130),
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: const Color(0xFF2e3150)),
          ),
          child: Text(keyLabel, textAlign: TextAlign.center,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Color(0xFF00d4d4))),
        ),
        const SizedBox(width: 16),
        Text(description, style: const TextStyle(fontSize: 13, color: Color(0xFFcbd5e1))),
      ]),
    );
  }
}
