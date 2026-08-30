import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:show_talent/models/user.dart';
import 'package:show_talent/models/video.dart';
import 'package:show_talent/screens/video_player.dart';

import '../controller/user_controller.dart';
import '../controller/video_controller.dart';
import '../theme/admin_theme.dart';
import '../widgets/admin_feedback.dart';
import '../widgets/admin_ui.dart';
import '../widgets/admin_video_ui.dart';

class VideoReportedWidget extends StatefulWidget {
  const VideoReportedWidget({super.key});

  @override
  State<VideoReportedWidget> createState() => _VideoReportedWidgetState();
}

class _VideoReportedWidgetState extends State<VideoReportedWidget> {
  static const int rowsPerPage = 4;

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
    return trimmed.length > 10 ? '${trimmed.substring(0, 10)}...' : trimmed;
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

  Widget _buildPreview(Video video, bool compact) {
    return AdminVideoPreviewCard(
      thumbnailUrl: video.thumbnail,
      statusLabel: '${video.reportCount} alertes',
      statusColor: AdminTheme.warning,
      footerLabel: _compactVideoId(video.id),
      footerIcon: Icons.flag_outlined,
      fallbackIcon: Icons.warning_amber_rounded,
      compact: compact,
    );
  }

  Widget _buildTitleCell(Video video) {
    return AdminVideoTitleCell(
      title: video.displayTitle,
      subtitle: _secondaryLabel(video),
      metadata: _metadata(video),
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

  Widget _buildActions(
    BuildContext context,
    Video video,
    List<Video> queue,
  ) {
    if (_deletingVideoId == video.id) {
      return const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        AdminVideoActionButton(
          onPressed: () => _openVideo(context, video, queue),
          icon: Icons.play_circle_outline_rounded,
          label: 'Analyser',
          tone: AdminVideoActionTone.info,
        ),
        AdminVideoActionButton(
          onPressed: () => _confirmDelete(context, video.id),
          icon: Icons.delete_outline_rounded,
          label: 'Supprimer',
          tone: AdminVideoActionTone.danger,
          outlined: true,
        ),
      ],
    );
  }

  Widget _buildVideoCard(
    BuildContext context,
    Video video,
    List<Video> queue,
  ) {
    return AdminDataCard(
      leading: _buildPreview(video, true),
      title: _buildTitleCell(video),
      fields: [
        AdminDataCardField(
          label: 'Ajoutée par',
          value: Text(_resolveUserName(video.uid)),
        ),
      ],
      actions: _buildActions(context, video, queue),
    );
  }

  @override
  Widget build(BuildContext context) {
    final compact = _isCompactLayout(context);
    final panelPadding = compact ? 16.0 : 22.0;
    final spacing = compact ? 12.0 : 16.0;
    final tableColumnSpacing = compact ? 16.0 : 24.0;
    final rowHeight = compact ? 112.0 : 122.0;

    return AdminGlassPanel(
      padding: EdgeInsets.all(panelPadding),
      highlight: true,
      accentColor: AdminTheme.warning,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(vertical: compact ? 10 : 12),
            child: AdminSearchField(
              controller: _searchController,
              maxWidth: 640,
              hintText: 'Rechercher une vidéo signalée',
              onChanged: (value) {
                setState(() {
                  searchQuery = value.toLowerCase();
                  currentPage = 0;
                });
              },
            ),
          ),
          Obx(() {
            final reportedVideos = videoController.getReportedVideos();
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
            final displayedVideos = filteredVideos.sublist(
              startIndex,
              endIndex,
            );

            if (videoController.isLoading.value) {
              return const Center(
                child: AdminLoadingState(
                  message: 'Chargement des signalements...',
                ),
              );
            }

            if (filteredVideos.isEmpty) {
              final hasSearch = searchQuery.trim().isNotEmpty;

              return AdminEmptyState(
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
            }

            final totalReports = filteredVideos.fold<int>(
              0,
              (sum, video) => sum + video.reportCount,
            );

            return Column(
              children: [
                Wrap(
                  spacing: compact ? 10 : 12,
                  runSpacing: compact ? 10 : 12,
                  children: [
                    AdminMiniStat(
                      label: 'Vidéos signalées',
                      value: '${reportedVideos.length}',
                      icon: Icons.report_gmailerrorred_outlined,
                      accentColor: AdminTheme.warning,
                      subtitle: 'À traiter',
                      minWidth: compact ? 180 : 220,
                    ),
                    AdminMiniStat(
                      label: 'Résultats',
                      value: '${filteredVideos.length}',
                      icon: Icons.filter_alt_outlined,
                      accentColor: AdminTheme.cyan,
                      subtitle: 'Après filtres',
                      minWidth: compact ? 180 : 220,
                    ),
                    AdminMiniStat(
                      label: 'Signalements reçus',
                      value: '$totalReports',
                      icon: Icons.flag_circle_outlined,
                      accentColor: AdminTheme.danger,
                      subtitle: 'Sélection affichée',
                      minWidth: compact ? 180 : 220,
                    ),
                  ],
                ),
                SizedBox(height: spacing),
                if (compact)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final video in displayedVideos) ...[
                        _buildVideoCard(context, video, filteredVideos),
                        const SizedBox(height: 12),
                      ],
                    ],
                  )
                else
                  AdminDataTableCard(
                    compact: compact,
                    child: DataTable(
                      columnSpacing: tableColumnSpacing,
                      horizontalMargin: compact ? 10 : 12,
                      columns: const [
                        DataColumn(label: Text('Aperçu')),
                        DataColumn(label: Text('Contenu')),
                        DataColumn(label: Text('Ajoutée par')),
                        DataColumn(label: Text('Signalements')),
                        DataColumn(label: Text('Actions')),
                      ],
                      rows: List<DataRow>.generate(displayedVideos.length, (
                        index,
                      ) {
                        final video = displayedVideos[index];
                        return DataRow(
                          cells: [
                            DataCell(_buildPreview(video, compact)),
                            DataCell(_buildTitleCell(video)),
                            DataCell(Text(_resolveUserName(video.uid))),
                            DataCell(
                              AdminPill(
                                label: '${video.reportCount} signalement(s)',
                                icon: Icons.flag_outlined,
                                color: AdminTheme.warning,
                              ),
                            ),
                            DataCell(_buildActions(context, video, filteredVideos)),
                          ],
                        );
                      }),
                      headingRowColor: WidgetStateProperty.all(
                        AdminTheme.surfaceHighlight.withValues(alpha: 0.72),
                      ),
                      dataRowColor: WidgetStateProperty.all(
                        AdminTheme.surface.withValues(alpha: 0.14),
                      ),
                      dividerThickness: 1,
                      dataRowMinHeight: rowHeight,
                      dataRowMaxHeight: rowHeight,
                      headingRowHeight: compact ? 50 : 54,
                    ),
                  ),
                SizedBox(height: spacing),
                AdminPaginationBar(
                  currentPage: safePage,
                  totalPages: totalPages,
                  onPrevious: safePage > 0
                      ? () {
                          setState(() {
                            currentPage = safePage - 1;
                          });
                        }
                      : null,
                  onNext: safePage < totalPages - 1
                      ? () {
                          setState(() {
                            currentPage = safePage + 1;
                          });
                        }
                      : null,
                ),
              ],
            );
          }),
        ],
      ),
    );
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

    if (confirmed != true) {
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
