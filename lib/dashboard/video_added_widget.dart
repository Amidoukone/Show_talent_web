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

class VideoAddedWidget extends StatefulWidget {
  const VideoAddedWidget({super.key});

  @override
  State<VideoAddedWidget> createState() => _VideoAddedWidgetState();
}

class _VideoAddedWidgetState extends State<VideoAddedWidget> {
  static const int rowsPerPage = 4;

  final VideoController videoController = Get.find<VideoController>();
  final UserController userController = Get.find<UserController>();
  final TextEditingController _searchController = TextEditingController();

  String searchQuery = '';
  int currentPage = 0;
  String? _deletingVideoId;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _isCompactLayout(BuildContext context) =>
      MediaQuery.sizeOf(context).width < 1120;

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
    switch (video.normalizedModerationStatus) {
      case 'approved':
        return AdminTheme.success;
      case 'pending':
        return AdminTheme.warning;
      case 'rejected':
      case 'removed':
        return AdminTheme.danger;
      case 'hidden':
        return AdminTheme.textMuted;
      default:
        return AdminTheme.cyan;
    }
  }

  String _secondaryLabel(Video video) {
    final songName = video.songName.trim();
    if (songName.isNotEmpty &&
        songName.toLowerCase() != video.displayTitle.trim().toLowerCase()) {
      return songName;
    }
    return video.isApprovedPublic
        ? 'Catalogue public'
        : 'Statut ${video.moderationLabel.toLowerCase()}';
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
        label: video.moderationLabel,
        icon: Icons.fact_check_outlined,
        color: _statusColor(video),
      ),
      AdminVideoMetaItem(
        label: video.isApprovedPublic ? 'Visible' : 'Non publique',
        icon: video.isApprovedPublic
            ? Icons.public_rounded
            : Icons.lock_outline_rounded,
        color:
            video.isApprovedPublic ? AdminTheme.success : AdminTheme.textMuted,
      ),
      if (video.reportCount > 0)
        AdminVideoMetaItem(
          label: '${video.reportCount} signalement(s)',
          icon: Icons.flag_outlined,
          color: AdminTheme.warning,
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
      statusLabel: video.moderationLabel,
      statusColor: _statusColor(video),
      footerLabel: _compactVideoId(video.id),
      footerIcon: Icons.ondemand_video_outlined,
      fallbackIcon: Icons.video_library_outlined,
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

  void _openVideo(Video video) {
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

    Get.to(
      () => VideoPlayerScreen(
        videoUrl: videoUrl,
        userId: video.uid,
        videoId: video.id,
      ),
    );
  }

  Widget _buildActions(BuildContext context, Video video) {
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
          onPressed: () => _openVideo(video),
          icon: Icons.play_circle_outline_rounded,
          label: 'Lire',
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
      accentColor: AdminTheme.accentSoft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AdminSectionHeader(
            badge: 'Catalogue vidéo',
            title: 'Gestion des vidéos',
            subtitle:
                'Consultez les contenus publiés, lancez la lecture et retirez les vidéos non conformes.',
          ),
          SizedBox(height: spacing),
          const AdminInfoBanner(
            title: 'Catalogue centralisé',
            message:
                'Les aperçus, auteurs et états de diffusion sont regroupés pour une modération rapide.',
            icon: Icons.video_collection_outlined,
            tone: AdminBannerTone.info,
          ),
          Padding(
            padding: EdgeInsets.symmetric(vertical: compact ? 10 : 12),
            child: AdminSearchField(
              controller: _searchController,
              maxWidth: 640,
              hintText: 'Rechercher par titre, statut ou joueur',
              onChanged: (value) {
                setState(() {
                  searchQuery = value.toLowerCase();
                  currentPage = 0;
                });
              },
            ),
          ),
          Obx(() {
            final allVideos = videoController.getAllVideos();
            final filteredVideos = allVideos.where((video) {
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
            final displayedVideos =
                filteredVideos.sublist(startIndex, endIndex);

            if (filteredVideos.isEmpty) {
              final hasSearch = searchQuery.trim().isNotEmpty;

              return AdminEmptyState(
                title: 'Aucune vidéo disponible',
                message:
                    'Le catalogue ne contient encore aucun élément correspondant à la recherche.',
                icon: Icons.slow_motion_video_rounded,
                actionLabel: hasSearch
                    ? 'Effacer la recherche'
                    : 'Recharger le catalogue',
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

            final reportedCount =
                allVideos.where((video) => video.reportCount > 0).length;
            final multiSourceCount =
                allVideos.where((video) => video.hasMultipleMp4Sources).length;
            final publicCount =
                allVideos.where((video) => video.isApprovedPublic).length;
            final pendingCount =
                allVideos.where((video) => video.isPendingReview).length;

            return Column(
              children: [
                Wrap(
                  spacing: compact ? 10 : 12,
                  runSpacing: compact ? 10 : 12,
                  children: [
                    AdminMiniStat(
                      label: 'Catalogue visible',
                      value: '${filteredVideos.length}',
                      icon: Icons.video_collection_outlined,
                      accentColor: AdminTheme.cyan,
                      subtitle: 'Après recherche',
                      minWidth: compact ? 180 : 220,
                    ),
                    AdminMiniStat(
                      label: 'Total vidéos',
                      value: '${allVideos.length}',
                      icon: Icons.ondemand_video_outlined,
                      accentColor: AdminTheme.accent,
                      subtitle: 'Catalogue global',
                      minWidth: compact ? 180 : 220,
                    ),
                    AdminMiniStat(
                      label: 'Signalées',
                      value: '$reportedCount',
                      icon: Icons.flag_outlined,
                      accentColor: AdminTheme.warning,
                      subtitle: 'Dans le catalogue',
                      minWidth: compact ? 180 : 220,
                    ),
                    AdminMiniStat(
                      label: 'Publiques',
                      value: '$publicCount',
                      icon: Icons.public_rounded,
                      accentColor: AdminTheme.success,
                      subtitle: 'Visibles recruteurs',
                      minWidth: compact ? 180 : 220,
                    ),
                    AdminMiniStat(
                      label: 'En attente',
                      value: '$pendingCount',
                      icon: Icons.pending_actions_rounded,
                      accentColor: AdminTheme.warning,
                      subtitle: 'Revue admin',
                      minWidth: compact ? 180 : 220,
                    ),
                    AdminMiniStat(
                      label: 'Sources prêtes',
                      value: '$multiSourceCount',
                      icon: Icons.dynamic_feed_outlined,
                      accentColor: AdminTheme.success,
                      subtitle: 'Lecture multi-support',
                      minWidth: compact ? 180 : 220,
                    ),
                  ],
                ),
                SizedBox(height: spacing),
                AdminDataTableCard(
                  compact: compact,
                  child: DataTable(
                    columnSpacing: tableColumnSpacing,
                    horizontalMargin: compact ? 10 : 12,
                    columns: const [
                      DataColumn(label: Text('Aperçu')),
                      DataColumn(label: Text('Contenu')),
                      DataColumn(label: Text('Ajoutée par')),
                      DataColumn(label: Text('Statut')),
                      DataColumn(label: Text('Actions')),
                    ],
                    rows: List<DataRow>.generate(
                      displayedVideos.length,
                      (index) {
                        final video = displayedVideos[index];
                        return DataRow(
                          cells: [
                            DataCell(_buildPreview(video, compact)),
                            DataCell(_buildTitleCell(video)),
                            DataCell(Text(_resolveUserName(video.uid))),
                            DataCell(
                              AdminPill(
                                label: video.moderationLabel,
                                icon: Icons.fact_check_outlined,
                                color: _statusColor(video),
                              ),
                            ),
                            DataCell(_buildActions(context, video)),
                          ],
                        );
                      },
                    ),
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

  void _confirmDelete(BuildContext context, String videoId) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Supprimer la vidéo'),
          content: const Text(
            'Cette action retire définitivement la vidéo du catalogue et de la modération.',
          ),
          actions: [
            TextButton(
              onPressed: Get.back,
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                setState(() {
                  _deletingVideoId = videoId;
                });

                try {
                  await videoController.deleteVideo(videoId);
                  showAdminFeedback(
                    title: 'Vidéo supprimée',
                    message: 'La vidéo a été retirée avec succès.',
                    tone: AdminBannerTone.success,
                    position: SnackPosition.BOTTOM,
                  );
                } catch (error) {
                  showAdminFeedback(
                    title: 'Suppression impossible',
                    message: '$error',
                    tone: AdminBannerTone.danger,
                    position: SnackPosition.BOTTOM,
                  );
                } finally {
                  if (mounted) {
                    setState(() {
                      _deletingVideoId = null;
                    });
                  }
                }
              },
              child: const Text('Supprimer'),
            ),
          ],
        );
      },
    );
  }
}
