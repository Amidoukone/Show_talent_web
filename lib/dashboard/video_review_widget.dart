import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:show_talent/models/user.dart';
import 'package:show_talent/models/video.dart';
import 'package:show_talent/screens/video_player.dart';

import '../controller/user_controller.dart';
import '../controller/video_controller.dart';
import '../theme/admin_theme.dart';
import '../widgets/admin_feedback.dart';
import '../widgets/admin_page.dart';
import '../widgets/admin_table.dart';
import '../widgets/admin_ui.dart';
import '../widgets/admin_video_ui.dart';

class VideoReviewWidget extends StatefulWidget {
  const VideoReviewWidget({super.key});

  @override
  State<VideoReviewWidget> createState() => _VideoReviewWidgetState();
}

class _VideoReviewWidgetState extends State<VideoReviewWidget> {
  static const int rowsPerPage = 25;

  final VideoController videoController = Get.find<VideoController>();
  final UserController userController = Get.find<UserController>();
  final TextEditingController _searchController = TextEditingController();

  String searchQuery = '';
  int currentPage = 0;
  String? _processingVideoId;
  String? _processingAction;
  bool _isOpeningVideo = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _isCompactLayout(BuildContext context) =>
      MediaQuery.sizeOf(context).width < AdminTheme.breakpointCompact;

  String _resolveUserName(String uid) {
    return userController.userList
        .firstWhere(
          (user) => user.uid == uid,
          orElse: () => AppUser(
            nom: 'Inconnu',
            uid: '',
            email: '',
            role: '',
            photoProfil: '',
            estActif: true,
            authDisabled: false,
            createdByAdmin: false,
            followers: 0,
            followings: 0,
            dateInscription: DateTime.now(),
            dernierLogin: DateTime.now(),
          ),
        )
        .nom;
  }

  Color _statusColor(Video video) {
    if (!video.optimized) {
      return AdminTheme.warning;
    }

    switch (video.normalizedModerationStatus) {
      case 'approved':
        return AdminTheme.success;
      case 'rejected':
      case 'removed':
        return AdminTheme.danger;
      case 'hidden':
        return AdminTheme.textMuted;
      case 'pending':
      default:
        return AdminTheme.warning;
    }
  }

  String _statusLabel(Video video) {
    if (!video.optimized) {
      return 'Optimisation';
    }
    return 'Prête à publier';
  }

  String _secondaryLabel(Video video) {
    final songName = video.songName.trim();
    if (songName.isNotEmpty &&
        songName.toLowerCase() != video.displayTitle.trim().toLowerCase()) {
      return songName;
    }
    return 'Référence ${_compactVideoId(video.id)}';
  }

  String _compactVideoId(String id) {
    final trimmed = id.trim();
    if (trimmed.isEmpty) {
      return 'inconnue';
    }
    return trimmed.length > 10 ? '${trimmed.substring(0, 10)}…' : trimmed;
  }

  List<AdminVideoMetaItem> _metadata(Video video) {
    return [
      AdminVideoMetaItem(
        label: video.optimized ? 'Décision possible' : 'Traitement en cours',
        icon: video.optimized
            ? Icons.verified_outlined
            : Icons.autorenew_rounded,
        color: _statusColor(video),
      ),
      AdminVideoMetaItem(
        label: video.hasMultipleMp4Sources ? 'MP4 multi-source' : 'MP4 prêt',
        icon: Icons.hd_rounded,
        color: AdminTheme.cyan,
      ),
      if (video.reportCount > 0)
        AdminVideoMetaItem(
          label: '${video.reportCount} signalement(s)',
          icon: Icons.flag_outlined,
          color: AdminTheme.warning,
        ),
    ];
  }

  /// Les décisions proposées dans le lecteur pour [video].
  ///
  /// Elles délèguent aux mêmes méthodes que la liste : une seule règle
  /// métier, deux points d'entrée.
  List<AdminVideoDecision> _playerDecisions(Video video) {
    return [
      AdminVideoDecision(
        label: 'Approuver',
        icon: Icons.check_circle_outline_rounded,
        tone: AdminVideoActionTone.success,
        onInvoke: () => _approveVideo(video),
      ),
      AdminVideoDecision(
        label: 'Refuser',
        icon: Icons.delete_outline_rounded,
        tone: AdminVideoActionTone.danger,
        outlined: true,
        onInvoke: () => _rejectVideo(video),
      ),
    ];
  }

  AdminVideoQueueEntry _queueEntry(Video video) {
    return AdminVideoQueueEntry(
      videoUrl: video.effectiveUrl,
      userId: video.uid,
      videoId: video.id,
      title: video.displayTitle,
      authorName: _resolveUserName(video.uid),
      metadata: _metadata(video),
      decisions: _playerDecisions(video),
    );
  }

  Future<void> _openVideo(Video video, List<Video> queue) async {
    if (_isOpeningVideo) return;

    final videoUrl = video.effectiveUrl;
    if (videoUrl.isEmpty) {
      showAdminFeedback(
        title: 'Lecture indisponible',
        message: 'Aucune source MP4 exploitable pour cette vidéo.',
        tone: AdminBannerTone.warning,
        position: SnackPosition.BOTTOM,
      );
      return;
    }

    // La file suit ce que l'opérateur voit : la recherche en cours, dans son
    // ordre, et non la seule page affichée. Les vidéos sans source lisible en
    // sont retirées — sauf celle qu'on vient d'ouvrir, déjà écartée plus haut.
    final entries = queue
        .where((candidate) => candidate.effectiveUrl.isNotEmpty)
        .toList(growable: false);
    final startIndex = entries.indexWhere(
      (candidate) => candidate.id == video.id,
    );

    // A rapid double-tap could otherwise push two VideoPlayerScreen routes
    // and start two network video downloads before the first navigation
    // transition completes. Guarded for the entire time the preview is
    // open, not just a short debounce window.
    _isOpeningVideo = true;
    try {
      await Get.to(
        () => VideoPlayerScreen.queue(
          entries: entries.isEmpty
              ? [_queueEntry(video)]
              : entries.map(_queueEntry).toList(growable: false),
          initialIndex: startIndex < 0 ? 0 : startIndex,
        ),
      );
    } finally {
      _isOpeningVideo = false;
    }
  }

  Future<bool> _approveVideo(Video video) async {
    if (!video.optimized) {
      showAdminFeedback(
        title: 'Optimisation en cours',
        message: "Attendez la fin de l’optimisation avant de publier.",
        tone: AdminBannerTone.warning,
        position: SnackPosition.BOTTOM,
      );
      return false;
    }

    setState(() {
      _processingVideoId = video.id;
      _processingAction = 'approve';
    });

    try {
      await videoController.approveVideo(video.id);
      showAdminFeedback(
        title: 'Vidéo approuvée',
        message:
            'La vidéo est maintenant visible par les clubs et les recruteurs.',
        tone: AdminBannerTone.success,
        position: SnackPosition.BOTTOM,
      );
      return true;
    } catch (error) {
      showAdminFeedback(
        title: 'Approbation impossible',
        message: '$error',
        tone: AdminBannerTone.danger,
        position: SnackPosition.BOTTOM,
      );
      return false;
    } finally {
      if (mounted) {
        setState(() {
          _processingVideoId = null;
          _processingAction = null;
        });
      }
    }
  }

  Future<bool> _rejectVideo(Video video) async {
    final reason = await _askRejectionReason(video);
    if (reason == null) {
      return false;
    }

    setState(() {
      _processingVideoId = video.id;
      _processingAction = 'reject';
    });

    try {
      await videoController.rejectVideo(video.id, reason: reason);
      showAdminFeedback(
        title: 'Vidéo refusée',
        message: 'La vidéo a été supprimée et le joueur sera notifié.',
        tone: AdminBannerTone.success,
        position: SnackPosition.BOTTOM,
      );
      return true;
    } catch (error) {
      showAdminFeedback(
        title: 'Refus impossible',
        message: '$error',
        tone: AdminBannerTone.danger,
        position: SnackPosition.BOTTOM,
      );
      return false;
    } finally {
      if (mounted) {
        setState(() {
          _processingVideoId = null;
          _processingAction = null;
        });
      }
    }
  }

  Future<String?> _askRejectionReason(Video video) async {
    final controller = TextEditingController();
    try {
      return await showDialog<String?>(
        context: context,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              final hasReason = controller.text.trim().isNotEmpty;
              return AlertDialog(
                title: const Text('Refuser la vidéo'),
                content: SizedBox(
                  width: 480,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        video.displayTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: controller,
                        maxLines: 3,
                        maxLength: 500,
                        onChanged: (_) => setDialogState(() {}),
                        decoration: InputDecoration(
                          labelText: 'Motif envoyé au joueur',
                          hintText:
                              'Exemple : action peu visible, qualité insuffisante…',
                          errorText: hasReason
                              ? null
                              // This deletes the video permanently once
                              // confirmed -- a reason is required so an
                              // empty-text misclick can't slip through.
                              : 'Un motif est requis avant suppression.',
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(null),
                    child: const Text('Annuler'),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AdminTheme.danger,
                      foregroundColor: AdminTheme.background,
                    ),
                    onPressed: hasReason
                        ? () =>
                              Navigator.of(context).pop(controller.text.trim())
                        : null,
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text('Refuser et supprimer'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      controller.dispose();
    }
  }

  Widget _buildPreview(Video video, {required bool dense}) {
    return AdminVideoPreviewCard(
      thumbnailUrl: video.thumbnail,
      statusColor: _statusColor(video),
      dense: dense,
    );
  }

  Widget _buildTitleCell(Video video) {
    return AdminVideoTitleCell(
      title: video.displayTitle,
      subtitle: _secondaryLabel(video),
    );
  }

  /// Actions d'une ligne : prévisualiser, approuver, refuser.
  ///
  /// Les trois sont en clair — c'est exactement le travail de cet écran, il
  /// n'y a rien à cacher derrière un menu. « Approuver » reste désactivé
  /// tant que l'optimisation n'est pas terminée, mais visible : l'opérateur
  /// voit que la décision existe et qu'elle n'est pas encore possible.
  Widget _buildActions(Video video, List<Video> queue) {
    return AdminRowActions(
      busy: _processingVideoId == video.id,
      busyLabel: _processingAction == 'approve' ? 'Validation…' : 'Refus…',
      primary: [
        AdminRowAction(
          icon: Icons.play_circle_outline_rounded,
          label: 'Prévisualiser',
          color: AdminTheme.cyan,
          onPressed: () => _openVideo(video, queue),
        ),
        AdminRowAction(
          icon: Icons.check_circle_outline_rounded,
          label: video.optimized
              ? 'Approuver'
              : 'Approuver (optimisation en cours)',
          color: AdminTheme.success,
          onPressed: video.optimized ? () => _approveVideo(video) : null,
        ),
        AdminRowAction(
          icon: Icons.cancel_outlined,
          label: 'Refuser',
          color: AdminTheme.danger,
          onPressed: () => _rejectVideo(video),
        ),
      ],
    );
  }

  Widget _buildVideoCard(Video video, List<Video> queue) {
    return AdminDataCard(
      onTap: () => _openVideo(video, queue),
      leading: _buildPreview(video, dense: false),
      title: _buildTitleCell(video),
      trailing: AdminPill(
        label: _statusLabel(video),
        icon: video.optimized
            ? Icons.verified_outlined
            : Icons.autorenew_rounded,
        color: _statusColor(video),
      ),
      fields: [
        AdminDataCardField(
          label: 'Joueur',
          value: Text(_resolveUserName(video.uid)),
        ),
      ],
      actions: _buildActions(video, queue),
    );
  }

  @override
  Widget build(BuildContext context) {
    final compact = _isCompactLayout(context);

    final toolbar = AdminToolbar(
      filters: [
        AdminSearchField(
          controller: _searchController,
          hintText: 'Rechercher par titre, référence ou joueur',
          onChanged: (value) {
            setState(() {
              searchQuery = value.toLowerCase();
              currentPage = 0;
            });
          },
        ),
      ],
      trailing: [
        IconButton(
          onPressed: videoController.fetchVideos,
          icon: const Icon(Icons.refresh_rounded, size: 17),
          tooltip: 'Recharger la file',
        ),
      ],
    );

    return Obx(() {
      final allVideos = videoController.getAllVideos();

      if (videoController.isLoading.value) {
        return const AdminLoadingState(message: 'Chargement des vidéos…');
      }

      final loadError = videoController.lastError.value;
      if (loadError.isNotEmpty) {
        return AdminEmptyState(
          title: 'Chargement incomplet',
          message: loadError,
          icon: Icons.error_outline_rounded,
          actionLabel: 'Réessayer',
          actionIcon: Icons.refresh_rounded,
          onAction: videoController.fetchVideos,
        );
      }

      final pendingVideos = allVideos
          .where((video) => video.isPendingReview)
          .toList();
      final readyForDecision = pendingVideos
          .where((video) => video.optimized)
          .length;
      final processingCount = pendingVideos.length - readyForDecision;
      final publishedCount = allVideos
          .where((video) => video.isApprovedPublic)
          .length;

      final filteredVideos = pendingVideos.where((video) {
        final normalizedQuery = searchQuery.trim().toLowerCase();
        if (normalizedQuery.isEmpty) {
          return true;
        }

        return [
          video.displayTitle,
          video.songName,
          video.uid,
          _resolveUserName(video.uid),
          video.status,
          video.moderationStatus,
          video.id,
        ].any((value) => value.toLowerCase().contains(normalizedQuery));
      }).toList();

      final totalPagesRaw = (filteredVideos.length / rowsPerPage).ceil();
      final totalPages = totalPagesRaw < 1 ? 1 : totalPagesRaw;
      final safePage = currentPage >= totalPages
          ? totalPages - 1
          : currentPage.clamp(0, totalPages - 1);
      final startIndex = safePage * rowsPerPage;
      final endIndex = (startIndex + rowsPerPage).clamp(
        0,
        filteredVideos.length,
      );
      final displayedVideos = filteredVideos.sublist(startIndex, endIndex);

      final stats = AdminStatStrip(
        stats: [
          AdminStat(
            label: 'en attente',
            value: '${pendingVideos.length}',
            tone: pendingVideos.isEmpty ? null : AdminTheme.warning,
          ),
          AdminStat(
            label: 'prêtes à décider',
            value: '$readyForDecision',
            tone: readyForDecision > 0 ? AdminTheme.success : null,
          ),
          AdminStat(label: 'en optimisation', value: '$processingCount'),
          AdminStat(label: 'publiées', value: '$publishedCount'),
        ],
      );

      final Widget body;
      if (filteredVideos.isEmpty) {
        final hasSearch = searchQuery.trim().isNotEmpty;
        body = AdminEmptyState(
          title: 'Aucune vidéo en attente',
          message: hasSearch
              ? 'Aucune vidéo en attente ne correspond à cette recherche.'
              : 'La file de revue est vide.',
          icon: Icons.task_alt_rounded,
          actionLabel: hasSearch ? 'Effacer la recherche' : 'Recharger la file',
          actionIcon: hasSearch
              ? Icons.filter_alt_off_rounded
              : Icons.refresh_rounded,
          onAction: () {
            if (hasSearch) {
              setState(() {
                searchQuery = '';
                currentPage = 0;
                _searchController.clear();
              });
            } else {
              videoController.fetchVideos();
            }
          },
        );
      } else if (compact) {
        body = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final video in displayedVideos) ...[
              _buildVideoCard(video, filteredVideos),
              const SizedBox(height: AdminTheme.space2),
            ],
          ],
        );
      } else {
        body = AdminTable(
          rowHeight: 56,
          minWidth: 940,
          columns: const [
            AdminColumn(label: '', width: 80),
            AdminColumn(label: 'Contenu', flex: 4),
            AdminColumn(label: 'Joueur', flex: 2),
            AdminColumn(label: 'Statut', width: 148),
            AdminColumn(label: '', width: 108, alignRight: true),
          ],
          rowCount: displayedVideos.length,
          onRowTap: (index) =>
              _openVideo(displayedVideos[index], filteredVideos),
          cellsBuilder: (index) {
            final video = displayedVideos[index];

            return [
              _buildPreview(video, dense: true),
              _buildTitleCell(video),
              Text(
                _resolveUserName(video.uid),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              AdminPill(
                label: _statusLabel(video),
                icon: video.optimized
                    ? Icons.verified_outlined
                    : Icons.autorenew_rounded,
                color: _statusColor(video),
              ),
              _buildActions(video, filteredVideos),
            ];
          },
        );
      }

      return AdminWorkspace(
        compact: compact,
        bodyMinWidth: 940,
        toolbar: toolbar,
        stats: stats,
        body: body,
        footer: filteredVideos.isEmpty
            ? null
            : AdminListFooter(
                rangeStart: startIndex + 1,
                rangeEnd: endIndex,
                filteredCount: filteredVideos.length,
                currentPage: safePage,
                totalPages: totalPages,
                itemLabel: 'vidéos en attente',
                hasMore: videoController.hasMore.value,
                onLoadMore: videoController.loadMoreVideos,
                onPrevious: safePage > 0
                    ? () => setState(() => currentPage = safePage - 1)
                    : null,
                onNext: safePage < totalPages - 1
                    ? () => setState(() => currentPage = safePage + 1)
                    : null,
              ),
      );
    });
  }
}
