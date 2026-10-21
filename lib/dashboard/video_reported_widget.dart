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

class VideoReportedWidget extends StatefulWidget {
  const VideoReportedWidget({super.key});

  @override
  State<VideoReportedWidget> createState() => _VideoReportedWidgetState();
}

class _VideoReportedWidgetState extends State<VideoReportedWidget> {
  static const int rowsPerPage = 25;

  final VideoController videoController = Get.find<VideoController>();
  final UserController userController = Get.find<UserController>();
  final TextEditingController _searchController = TextEditingController();

  String searchQuery = '';
  int currentPage = 0;
  String? _deletingVideoId;
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

  String _secondaryLabel(Video video) {
    final songName = video.songName.trim();
    if (songName.isNotEmpty &&
        songName.toLowerCase() != video.displayTitle.trim().toLowerCase()) {
      return songName;
    }
    return '${video.reportCount} signalement(s) à analyser';
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
        label: '${video.reportCount} signalement(s)',
        icon: Icons.flag_outlined,
        color: AdminTheme.warning,
      ),
      AdminVideoMetaItem(
        label: video.moderationLabel,
        icon: Icons.fact_check_outlined,
        color: video.isApprovedPublic ? AdminTheme.success : AdminTheme.warning,
      ),
      if (video.shareCount > 0)
        AdminVideoMetaItem(
          label: '${video.shareCount} partage(s)',
          icon: Icons.share_outlined,
          color: AdminTheme.cyan,
        ),
    ];
  }

  Widget _buildPreview(Video video, {required bool dense}) {
    return AdminVideoPreviewCard(
      thumbnailUrl: video.thumbnail,
      statusColor: AdminTheme.warning,
      dense: dense,
      fallbackIcon: Icons.warning_amber_rounded,
    );
  }

  Widget _buildTitleCell(Video video) {
    return AdminVideoTitleCell(
      title: video.displayTitle,
      subtitle: _secondaryLabel(video),
    );
  }

  AdminVideoQueueEntry _queueEntry(BuildContext context, Video video) {
    return AdminVideoQueueEntry(
      videoUrl: video.effectiveUrl,
      userId: video.uid,
      videoId: video.id,
      title: video.displayTitle,
      authorName: _resolveUserName(video.uid),
      metadata: _metadata(video),
      decisions: [
        AdminVideoDecision(
          label: 'Supprimer',
          icon: Icons.delete_outline_rounded,
          tone: AdminVideoActionTone.danger,
          outlined: true,
          onInvoke: () => _confirmDelete(context, video.id),
        ),
      ],
    );
  }

  Future<void> _openVideo(
    BuildContext context,
    Video video,
    List<Video> queue,
  ) async {
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
    // ordre, et non la seule page affichée.
    final entries = queue
        .where((candidate) => candidate.effectiveUrl.isNotEmpty)
        .toList(growable: false);
    final startIndex = entries.indexWhere(
      (candidate) => candidate.id == video.id,
    );

    _isOpeningVideo = true;
    try {
      await Get.to(
        () => VideoPlayerScreen.queue(
          entries: entries.isEmpty
              ? [_queueEntry(context, video)]
              : entries
                    .map((candidate) => _queueEntry(context, candidate))
                    .toList(growable: false),
          initialIndex: startIndex < 0 ? 0 : startIndex,
        ),
      );
    } finally {
      _isOpeningVideo = false;
    }
  }

  /// Actions d'une ligne : analyser la vidéo dans le lecteur, supprimer.
  Widget _buildActions(BuildContext context, Video video, List<Video> queue) {
    return AdminRowActions(
      busy: _deletingVideoId == video.id,
      primary: [
        AdminRowAction(
          icon: Icons.play_circle_outline_rounded,
          label: 'Analyser',
          color: AdminTheme.cyan,
          onPressed: () => _openVideo(context, video, queue),
        ),
        AdminRowAction(
          icon: Icons.delete_outline_rounded,
          label: 'Supprimer',
          color: AdminTheme.danger,
          onPressed: () => _confirmDelete(context, video.id),
        ),
      ],
    );
  }

  Widget _buildVideoCard(BuildContext context, Video video, List<Video> queue) {
    return AdminDataCard(
      onTap: () => _openVideo(context, video, queue),
      leading: _buildPreview(video, dense: false),
      title: _buildTitleCell(video),
      trailing: AdminPill(
        label: '${video.reportCount}',
        icon: Icons.flag_outlined,
        color: AdminTheme.warning,
      ),
      fields: [
        AdminDataCardField(
          label: 'Ajoutée par',
          value: Text(_resolveUserName(video.uid)),
        ),
        AdminDataCardField(
          label: 'Référence',
          value: Text(_compactVideoId(video.id)),
        ),
      ],
      actions: _buildActions(context, video, queue),
    );
  }

  @override
  Widget build(BuildContext context) {
    final compact = _isCompactLayout(context);

    final toolbar = AdminToolbar(
      filters: [
        AdminSearchField(
          controller: _searchController,
          hintText: 'Rechercher une vidéo signalée',
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
          tooltip: 'Recharger les signalements',
        ),
      ],
    );

    return Obx(() {
      final reportedVideos = videoController.getReportedVideos();

      if (videoController.isLoading.value) {
        return const AdminLoadingState(
          message: 'Chargement des signalements…',
        );
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

      final filteredVideos = reportedVideos.where((video) {
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

      final totalReports = filteredVideos.fold<int>(
        0,
        (sum, video) => sum + video.reportCount,
      );

      final stats = AdminStatStrip(
        stats: [
          AdminStat(
            label: 'vidéos signalées',
            value: '${reportedVideos.length}',
            tone: reportedVideos.isEmpty ? null : AdminTheme.warning,
          ),
          AdminStat(
            label: 'signalements reçus',
            value: '$totalReports',
            tone: totalReports == 0 ? null : AdminTheme.warning,
          ),
        ],
      );

      final Widget body;
      if (filteredVideos.isEmpty) {
        final hasSearch = searchQuery.trim().isNotEmpty;
        body = AdminEmptyState(
          title: 'Aucune vidéo signalée',
          message: hasSearch
              ? 'Aucun signalement ne correspond à cette recherche.'
              : 'Aucune vidéo signalée pour le moment.',
          icon: Icons.report_off_outlined,
          actionLabel: hasSearch
              ? 'Effacer la recherche'
              : 'Recharger les signalements',
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
              _buildVideoCard(context, video, filteredVideos),
              const SizedBox(height: AdminTheme.space2),
            ],
          ],
        );
      } else {
        body = AdminTable(
          rowHeight: 56,
          columns: const [
            AdminColumn(label: '', width: 80),
            AdminColumn(label: 'Contenu', flex: 4),
            AdminColumn(label: 'Ajoutée par', flex: 2),
            AdminColumn(label: 'Signalements', width: 140),
            AdminColumn(label: '', width: 72, alignRight: true),
          ],
          rowCount: displayedVideos.length,
          onRowTap: (index) =>
              _openVideo(context, displayedVideos[index], filteredVideos),
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
                label: '${video.reportCount} signalement(s)',
                icon: Icons.flag_outlined,
                color: AdminTheme.warning,
              ),
              _buildActions(context, video, filteredVideos),
            ];
          },
        );
      }

      return AdminWorkspace(
        compact: compact,
        bodyMinWidth: 880,
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
                itemLabel: 'vidéos signalées',
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

  /// Rend `true` quand la vidéo signalée a réellement été supprimée.
  Future<bool> _confirmDelete(BuildContext context, String videoId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Supprimer la vidéo'),
          content: const Text(
            'Cette action retire définitivement la vidéo signalée et clôt la revue sur ce contenu.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AdminTheme.danger,
                foregroundColor: AdminTheme.background,
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Supprimer'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return false;
    }

    setState(() {
      _deletingVideoId = videoId;
    });

    try {
      await videoController.deleteVideo(videoId);
      showAdminFeedback(
        title: 'Vidéo supprimée',
        message: 'La vidéo signalée a été retirée avec succès.',
        tone: AdminBannerTone.success,
        position: SnackPosition.BOTTOM,
      );
      return true;
    } catch (error) {
      showAdminFeedback(
        title: 'Suppression impossible',
        message: '$error',
        tone: AdminBannerTone.danger,
        position: SnackPosition.BOTTOM,
      );
      return false;
    } finally {
      if (mounted) {
        setState(() {
          _deletingVideoId = null;
        });
      }
    }
  }
}
