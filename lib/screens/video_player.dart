import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../theme/admin_theme.dart';
import '../utils/browser_fullscreen.dart';
import '../utils/video_moderation_playback.dart';
import '../widgets/admin_ui.dart';
import '../widgets/admin_video_ui.dart';

typedef VideoModerationControllerFactory =
    VideoPlayerController Function(Uri uri);

/// Le lecteur de modération.
///
/// Il ne sert pas à regarder une vidéo mais à la juger : revenir de dix
/// secondes, ralentir une action, repasser le même geste, décider, puis
/// enchaîner sur la suivante sans repasser par la liste. Les décisions
/// elles-mêmes restent la propriété de l'écran appelant — voir
/// [AdminVideoDecision].
class VideoPlayerScreen extends StatefulWidget {
  /// Ouvre une vidéo seule.
  VideoPlayerScreen({
    required String videoUrl,
    required String userId,
    required String videoId,
    String? title,
    String? authorName,
    List<AdminVideoMetaItem> metadata = const <AdminVideoMetaItem>[],
    List<AdminVideoDecision> decisions = const <AdminVideoDecision>[],
    this.controllerFactory,
    super.key,
  }) : entries = <AdminVideoQueueEntry>[
         AdminVideoQueueEntry(
           videoUrl: videoUrl,
           userId: userId,
           videoId: videoId,
           title: title,
           authorName: authorName,
           metadata: metadata,
           decisions: decisions,
         ),
       ],
       initialIndex = 0;

  /// Ouvre une file de modération à la vidéo [initialIndex].
  const VideoPlayerScreen.queue({
    required this.entries,
    this.initialIndex = 0,
    this.controllerFactory,
    super.key,
  }) : assert(
         entries.length != 0,
         'La file doit contenir au moins une vidéo.',
       );

  final List<AdminVideoQueueEntry> entries;
  final int initialIndex;
  final VideoModerationControllerFactory? controllerFactory;

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late List<AdminVideoQueueEntry> _entries;
  late int _index;

  VideoPlayerController? _controller;
  Future<void>? _initializeVideo;

  /// Les réglages survivent au changement de vidéo : un opérateur qui a choisi
  /// 0,5x et coupé le son ne veut pas le refaire à chaque vidéo de la file.
  double _speed = 1;
  bool _looping = true;
  bool _muted = false;

  bool _immersive = false;

  /// Arrête l'écoute des sorties de plein écran décidées par le navigateur.
  late final void Function() _stopFullscreenWatch;

  /// Position visée pendant qu'on tire la barre, en millisecondes.
  ///
  /// Tant qu'elle vaut null la barre suit la lecture ; pendant un glissement
  /// elle suit le doigt, sinon la position lue écraserait le geste en cours.
  double? _scrubMs;

  String? _runningDecision;

  @override
  void initState() {
    super.initState();
    _entries = List<AdminVideoQueueEntry>.of(widget.entries);
    _index = widget.initialIndex.clamp(0, _entries.length - 1);
    _stopFullscreenWatch = listenBrowserFullscreen(_onBrowserFullscreenChanged);
    _loadCurrent();
  }

  @override
  void dispose() {
    _stopFullscreenWatch();
    // Quitter l'écran en laissant le navigateur en plein écran laisserait
    // l'opérateur devant une liste sans barre d'adresse ni onglets.
    if (_immersive) {
      unawaited(setBrowserFullscreen(false));
    }
    _disposeController();
    super.dispose();
  }

  /// Le navigateur peut sortir du plein écran sans nous prévenir — Échap, F11,
  /// changement d'onglet. La mise en page doit suivre, sinon le lecteur reste
  /// « en plein écran » dans une fenêtre qui ne l'est plus.
  void _onBrowserFullscreenChanged(bool active) {
    if (!mounted || active == _immersive) {
      return;
    }
    setState(() => _immersive = active);
  }

  void _disposeController() {
    final controller = _controller;
    if (controller == null) {
      return;
    }
    controller.removeListener(_onPlaybackChanged);
    controller.dispose();
    _controller = null;
  }

  void _loadCurrent() {
    _disposeController();

    final entry = _entries[_index];
    final uri = Uri.parse(entry.videoUrl);
    final factory = widget.controllerFactory;
    final controller = factory == null
        ? VideoPlayerController.networkUrl(uri)
        : factory(uri);

    controller.addListener(_onPlaybackChanged);
    _controller = controller;
    _scrubMs = null;
    _initializeVideo = controller.initialize().then((_) async {
      await controller.setLooping(_looping);
      await controller.setPlaybackSpeed(_speed);
      await controller.setVolume(_muted ? 0 : 1);
      await controller.play();
      if (mounted) {
        setState(() {});
      }
    });
  }

  void _onPlaybackChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  AdminVideoQueueEntry get _entry => _entries[_index];

  VideoPlayerValue get _value =>
      _controller?.value ?? const VideoPlayerValue.uninitialized();

  Duration get _position => _value.position;

  Duration get _total => _value.duration;

  bool get _isBusy => _runningDecision != null;

  bool get _hasQueue => _entries.length > 1;

  bool get _hasNext => _index < _entries.length - 1;

  bool get _hasPrevious => _index > 0;

  Future<void> _togglePlay() async {
    final controller = _controller;
    if (controller == null) return;

    if (controller.value.isPlaying) {
      await controller.pause();
    } else {
      await controller.play();
    }
  }

  Future<void> _seekBy(Duration step) async {
    final controller = _controller;
    if (controller == null) return;

    await controller.seekTo(
      seekBy(position: _position, step: step, total: _total),
    );
  }

  Future<void> _restart() async {
    final controller = _controller;
    if (controller == null) return;

    await controller.seekTo(Duration.zero);
    await controller.play();
  }

  Future<void> _applySpeed(double speed) async {
    await _controller?.setPlaybackSpeed(speed);
    if (!mounted) return;
    setState(() => _speed = speed);
  }

  Future<void> _toggleMute() async {
    final muted = !_muted;
    await _controller?.setVolume(muted ? 0 : 1);
    if (!mounted) return;
    setState(() => _muted = muted);
  }

  Future<void> _toggleLooping() async {
    final looping = !_looping;
    await _controller?.setLooping(looping);
    if (!mounted) return;
    setState(() => _looping = looping);
  }

  void _toggleImmersive() {
    final next = !_immersive;
    setState(() => _immersive = next);
    // Sur le web, le plein écran applicatif entraîne celui du navigateur ;
    // ailleurs c'est un appel sans effet. La mise en page ne dépend jamais du
    // résultat : un navigateur qui refuse laisse quand même l'image en grand.
    unawaited(setBrowserFullscreen(next));
  }

  void _goTo(int index) {
    if (index < 0 || index >= _entries.length || index == _index) {
      return;
    }

    setState(() => _index = index);
    _loadCurrent();
  }

  Future<void> _runDecision(AdminVideoDecision decision) async {
    if (_isBusy) {
      return;
    }

    setState(() => _runningDecision = decision.label);
    // La lecture continuerait derrière la boîte de confirmation, et le son
    // d'une vidéo qu'on est en train de refuser n'aide personne.
    await _controller?.pause();

    var applied = false;
    try {
      applied = await decision.onInvoke();
    } finally {
      if (mounted) {
        setState(() => _runningDecision = null);
      }
    }

    if (!mounted || !applied || !decision.closesPlayer) {
      return;
    }

    // La vidéo vient d'être traitée : elle quitte la file. S'il en reste, on
    // enchaîne — c'est tout l'intérêt de travailler par file — sinon on rend
    // la main à la liste.
    if (_entries.length <= 1) {
      Navigator.of(context).pop();
      return;
    }

    setState(() {
      _entries = List<AdminVideoQueueEntry>.of(_entries)..removeAt(_index);
      if (_index >= _entries.length) {
        _index = _entries.length - 1;
      }
    });
    _loadCurrent();
  }

  Map<ShortcutActivator, VoidCallback> get _shortcuts {
    return <ShortcutActivator, VoidCallback>{
      const SingleActivator(LogicalKeyboardKey.space): () => _togglePlay(),
      const SingleActivator(LogicalKeyboardKey.keyK): () => _togglePlay(),
      const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
          _seekBy(-videoModerationArrowStep),
      const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
          _seekBy(videoModerationArrowStep),
      const SingleActivator(LogicalKeyboardKey.arrowLeft, shift: true): () =>
          _seekBy(-videoModerationFineStep),
      const SingleActivator(LogicalKeyboardKey.arrowRight, shift: true): () =>
          _seekBy(videoModerationFineStep),
      const SingleActivator(LogicalKeyboardKey.keyJ): () =>
          _seekBy(-videoModerationCoarseStep),
      const SingleActivator(LogicalKeyboardKey.keyL): () =>
          _seekBy(videoModerationCoarseStep),
      const SingleActivator(LogicalKeyboardKey.keyM): () => _toggleMute(),
      const SingleActivator(LogicalKeyboardKey.keyR): () => _restart(),
      const SingleActivator(LogicalKeyboardKey.keyS): () =>
          _applySpeed(nextPlaybackSpeed(_speed)),
      const SingleActivator(LogicalKeyboardKey.keyF): _toggleImmersive,
      const SingleActivator(LogicalKeyboardKey.keyN): () => _goTo(_index + 1),
      const SingleActivator(LogicalKeyboardKey.keyP): () => _goTo(_index - 1),
      // Échap n'est capté qu'en plein écran : ailleurs, il doit garder le
      // comportement que l'opérateur attend de son navigateur.
      if (_immersive)
        const SingleActivator(LogicalKeyboardKey.escape): _toggleImmersive,
    };
  }

  @override
  Widget build(BuildContext context) {
    final compact =
        MediaQuery.sizeOf(context).width < AdminTheme.breakpointCompact;
    final stacked = compact || _immersive;

    return Scaffold(
      body: AdminAppBackground(
        padding: EdgeInsets.all(_immersive ? 8 : (compact ? 14 : 24)),
        child: CallbackShortcuts(
          bindings: _shortcuts,
          child: Focus(
            autofocus: true,
            child: Column(
              children: [
                if (!_immersive) ...[
                  _buildTopBar(),
                  SizedBox(height: compact ? 12 : 18),
                ],
                Expanded(
                  child: AdminGlassPanel(
                    padding: EdgeInsets.all(_immersive ? 10 : (compact ? 14 : 22)),
                    highlight: true,
                    accentColor: AdminTheme.cyan,
                    child: FutureBuilder<void>(
                      future: _initializeVideo,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState != ConnectionState.done) {
                          return const Center(
                            child: AdminLoadingState(
                              message: 'Chargement de la vidéo...',
                            ),
                          );
                        }

                        if (!_value.isInitialized) {
                          return _buildUnplayable(snapshot.error);
                        }

                        return _buildPlayer(stacked);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Row(
      children: [
        OutlinedButton.icon(
          onPressed: _isBusy ? null : () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded),
          label: const Text('Retour'),
        ),
        const SizedBox(width: 12),
        const AdminPill(
          label: 'Lecture vidéo',
          icon: Icons.play_circle_outline_rounded,
        ),
        if (_hasQueue) ...[
          const SizedBox(width: 8),
          AdminPill(
            label: 'Vidéo ${_index + 1} sur ${_entries.length}',
            icon: Icons.playlist_play_rounded,
            color: AdminTheme.accent,
          ),
        ],
      ],
    );
  }

  Widget _buildUnplayable(Object? error) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: AdminTheme.warning,
              size: 42,
            ),
            const SizedBox(height: 14),
            const Text(
              'Impossible de lire cette vidéo.',
              style: TextStyle(
                color: AdminTheme.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              // La source est affichée : neuf fois sur dix, une vidéo qui ne
              // se lance pas est une source absente ou expirée, et l'URL est
              // ce qui permet de le voir sans ouvrir la console.
              error == null
                  ? _entry.videoUrl
                  : '${_entry.videoUrl}\n\n$error',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AdminTheme.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 18),
            // Une source morte n'empêche ni de trancher ni de continuer la
            // file : c'est justement un cas où il faut pouvoir faire les deux.
            if (_hasQueue) _buildQueueBar(),
            const SizedBox(height: 12),
            _buildDecisionBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayer(bool stacked) {
    final videoArea = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(_immersive ? 14 : 26),
            child: ColoredBox(
              color: Colors.black,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: _value.aspectRatio,
                        child: VideoPlayer(_controller!),
                      ),
                    ),
                  ),
                  // Un clic sur l'image met en pause : le geste attendu quand
                  // on veut arrêter sur une action.
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _togglePlay,
                    ),
                  ),
                  if (_value.isBuffering)
                    const Positioned.fill(
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  if (_immersive)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: _ControlButton(
                        tooltip: 'Quitter le plein écran (Échap)',
                        icon: Icons.fullscreen_exit_rounded,
                        onPressed: _toggleImmersive,
                        active: true,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        _buildTimeline(),
        const SizedBox(height: 10),
        _buildTransportControls(stacked),
      ],
    );

    if (stacked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: videoArea),
          if (_hasQueue) ...[const SizedBox(height: 10), _buildQueueBar()],
          const SizedBox(height: 12),
          _buildDecisionBar(),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: videoArea),
        const SizedBox(width: 18),
        SizedBox(width: 320, child: _buildSidePanel()),
      ],
    );
  }

  Widget _buildTimeline() {
    final totalMs = _total.inMilliseconds.toDouble();
    final positionMs = _position.inMilliseconds
        .toDouble()
        .clamp(0, totalMs <= 0 ? 0 : totalMs)
        .toDouble();
    final value = _scrubMs ?? positionMs;

    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
          ),
          child: Slider(
            value: totalMs <= 0 ? 0 : value,
            max: totalMs <= 0 ? 1 : totalMs,
            activeColor: AdminTheme.cyan,
            inactiveColor: AdminTheme.surfaceHighlight,
            onChanged: totalMs <= 0
                ? null
                : (next) => setState(() => _scrubMs = next),
            onChangeEnd: totalMs <= 0
                ? null
                : (next) async {
                    await _controller?.seekTo(
                      Duration(milliseconds: next.round()),
                    );
                    if (mounted) {
                      setState(() => _scrubMs = null);
                    }
                  },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                formatPlaybackTimestamp(
                  Duration(milliseconds: value.round()),
                ),
                style: const TextStyle(
                  color: AdminTheme.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                formatPlaybackTimestamp(_total),
                style: const TextStyle(
                  color: AdminTheme.textSecondary,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTransportControls(bool stacked) {
    final playing = _value.isPlaying;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _ControlButton(
          tooltip: 'Revenir au début (R)',
          icon: Icons.replay_rounded,
          onPressed: _restart,
        ),
        _ControlButton(
          tooltip: 'Reculer de 10 s (J)',
          icon: Icons.replay_10_rounded,
          onPressed: () => _seekBy(-videoModerationCoarseStep),
        ),
        _ControlButton(
          tooltip: 'Reculer d’une seconde (Maj + gauche)',
          icon: Icons.keyboard_arrow_left_rounded,
          onPressed: () => _seekBy(-videoModerationFineStep),
        ),
        ElevatedButton.icon(
          onPressed: _togglePlay,
          icon: Icon(
            playing
                ? Icons.pause_circle_filled_rounded
                : Icons.play_circle_fill_rounded,
          ),
          label: Text(playing ? 'Pause' : 'Lecture'),
        ),
        _ControlButton(
          tooltip: 'Avancer d’une seconde (Maj + droite)',
          icon: Icons.keyboard_arrow_right_rounded,
          onPressed: () => _seekBy(videoModerationFineStep),
        ),
        _ControlButton(
          tooltip: 'Avancer de 10 s (L)',
          icon: Icons.forward_10_rounded,
          onPressed: () => _seekBy(videoModerationCoarseStep),
        ),
        PopupMenuButton<double>(
          tooltip: 'Vitesse de lecture (S)',
          initialValue: _speed,
          onSelected: _applySpeed,
          itemBuilder: (context) => [
            for (final speed in videoModerationSpeeds)
              PopupMenuItem<double>(
                value: speed,
                child: Text(formatPlaybackSpeed(speed)),
              ),
          ],
          child: Chip(
            avatar: const Icon(Icons.speed_rounded, size: 18),
            label: Text(formatPlaybackSpeed(_speed)),
          ),
        ),
        _ControlButton(
          tooltip: _looping ? 'Lecture en boucle activée' : 'Lecture simple',
          icon: _looping ? Icons.repeat_on_rounded : Icons.repeat_rounded,
          onPressed: _toggleLooping,
          active: _looping,
        ),
        _ControlButton(
          tooltip: _muted ? 'Réactiver le son (M)' : 'Couper le son (M)',
          icon: _muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
          onPressed: _toggleMute,
          active: !_muted,
        ),
        _ControlButton(
          tooltip: _immersive
              ? 'Quitter le plein écran (Échap)'
              : 'Plein écran (F)',
          icon: _immersive
              ? Icons.fullscreen_exit_rounded
              : Icons.fullscreen_rounded,
          onPressed: _toggleImmersive,
          active: _immersive,
        ),
        if (!stacked)
          const Padding(
            padding: EdgeInsets.only(left: 4),
            child: Text(
              'Espace : lecture  •  ← → : 5 s  •  Maj + ← → : 1 s  •  F : plein écran',
              style: TextStyle(color: AdminTheme.textMuted, fontSize: 12),
            ),
          ),
      ],
    );
  }

  Widget _buildQueueBar() {
    if (!_hasQueue) {
      return const SizedBox.shrink();
    }

    // Wrap plutôt que Row : cette barre vit aussi dans le panneau latéral de
    // 320 px, où deux boutons et un compteur ne tiennent pas sur une ligne.
    return Wrap(
      spacing: 10,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        OutlinedButton.icon(
          onPressed: _hasPrevious && !_isBusy ? () => _goTo(_index - 1) : null,
          icon: const Icon(Icons.skip_previous_rounded, size: 18),
          label: const Text('Précédente'),
        ),
        Text(
          '${_index + 1} / ${_entries.length}',
          style: const TextStyle(
            color: AdminTheme.textSecondary,
            fontWeight: FontWeight.w700,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        OutlinedButton.icon(
          onPressed: _hasNext && !_isBusy ? () => _goTo(_index + 1) : null,
          icon: const Icon(Icons.skip_next_rounded, size: 18),
          label: const Text('Suivante'),
        ),
      ],
    );
  }

  Widget _buildSidePanel() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdminSectionHeader(
            title: _entry.displayTitle,
            subtitle: _entry.authorName == null
                ? 'Référence ${_entry.videoId}'
                : 'Publiée par ${_entry.authorName}',
          ),
          const SizedBox(height: 14),
          if (_entry.metadata.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final item in _entry.metadata)
                  AdminPill(
                    label: item.label,
                    icon: item.icon,
                    color: item.color,
                  ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          _PanelRow(label: 'Référence vidéo', value: _entry.videoId),
          _PanelRow(label: 'Compte auteur', value: _entry.userId),
          _PanelRow(label: 'Durée', value: formatPlaybackTimestamp(_total)),
          if (_hasQueue) ...[
            const SizedBox(height: 14),
            _buildQueueBar(),
          ],
          const SizedBox(height: 18),
          _buildDecisionBar(),
        ],
      ),
    );
  }

  Widget _buildDecisionBar() {
    final decisions = _entry.decisions;
    if (decisions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Décision',
          style: TextStyle(
            color: AdminTheme.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            for (final decision in decisions)
              if (_runningDecision == decision.label)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                AdminVideoActionButton(
                  label: decision.label,
                  icon: decision.icon,
                  tone: decision.tone,
                  outlined: decision.outlined,
                  onPressed: _isBusy ? null : () => _runDecision(decision),
                ),
          ],
        ),
      ],
    );
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.active = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon),
      color: active ? AdminTheme.cyan : AdminTheme.textSecondary,
      style: IconButton.styleFrom(
        backgroundColor: AdminTheme.surfaceHighlight.withValues(alpha: 0.5),
      ),
    );
  }
}

class _PanelRow extends StatelessWidget {
  const _PanelRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                color: AdminTheme.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(color: AdminTheme.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
