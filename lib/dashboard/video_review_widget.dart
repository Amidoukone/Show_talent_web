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

class VideoReviewWidget extends StatefulWidget {
  const VideoReviewWidget({super.key});

  @override
  State<VideoReviewWidget> createState() => _VideoReviewWidgetState();
}

class _VideoReviewWidgetState extends State<VideoReviewWidget> {
  static const int rowsPerPage = 5;

  final VideoController videoController = Get.find<VideoController>();
  final UserController userController = Get.find<UserController>();
  final TextEditingController _searchController = TextEditingController();

  String searchQuery = '';
  int currentPage = 0;
  String? _processingVideoId;
  String? _processingAction;

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
    return trimmed.length > 10 ? '${trimmed.substring(0, 10)}...' : trimmed;
  }

  List<AdminVideoMetaItem> _metadata(Video video) {
    return [
      AdminVideoMetaItem(
        label: video.optimized ? 'Décision possible' : 'Traitement en cours',
        icon:
            video.optimized ? Icons.verified_outlined : Icons.autorenew_rounded,
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

  Future<void> _approveVideo(Video video) async {
    if (!video.optimized) {
      showAdminFeedback(
        title: 'Optimisation en cours',
        message: "Attendez la fin de l'optimisation avant de publier.",
        tone: AdminBannerTone.warning,
        position: SnackPosition.BOTTOM,
      );
      return;
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
    } catch (error) {
      showAdminFeedback(
        title: 'Approbation impossible',
        message: '$error',
        tone: AdminBannerTone.danger,
        position: SnackPosition.BOTTOM,
      );
    } finally {
      if (mounted) {
        setState(() {
          _processingVideoId = null;
          _processingAction = null;
        });
      }
    }
  }

  Future<void> _rejectVideo(Video video) async {
    final reason = await _askRejectionReason(video);
    if (reason == null) {
      return;
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
    } catch (error) {
      showAdminFeedback(
        title: 'Refus impossible',
        message: '$error',
        tone: AdminBannerTone.danger,
        position: SnackPosition.BOTTOM,
      );
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
                    decoration: const InputDecoration(
                      labelText: 'Motif envoyé au joueur',
                      hintText:
                          'Exemple : action peu visible, qualité insuffisante...',
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
                onPressed: () {
                  Navigator.of(context).pop(controller.text.trim());
                },
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Refuser et supprimer'),
              ),
            ],
          );
        },
      );
    } finally {
      controller.dispose();
    }
  }

  Widget _buildPreview(Video video, bool compact) {
    return AdminVideoPreviewCard(
      thumbnailUrl: video.thumbnail,
      statusLabel: video.optimized ? 'Prête' : 'Traitement',
      statusColor: _statusColor(video),
      footerLabel: _compactVideoId(video.id),
      footerIcon: Icons.videocam_outlined,
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

  Widget _buildActions(Video video) {
    final isBusy = _processingVideoId == video.id;
    if (isBusy) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 8),
          Text(
            _processingAction == 'approve' ? 'Validation...' : 'Refus...',
            style: const TextStyle(color: AdminTheme.textSecondary),
          ),
        ],
      );
    }

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        AdminVideoActionButton(
          onPressed: () => _openVideo(video),
          icon: Icons.play_circle_outline_rounded,
          label: 'Prévisualiser',
          tone: AdminVideoActionTone.info,
        ),
        AdminVideoActionButton(
          onPressed: video.optimized ? () => _approveVideo(video) : null,
          icon: Icons.check_circle_outline_rounded,
          label: 'Approuver',
          tone: AdminVideoActionTone.success,
        ),
        AdminVideoActionButton(
          onPressed: () => _rejectVideo(video),
          icon: Icons.delete_outline_rounded,
          label: 'Refuser',
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
      accentColor: AdminTheme.warning,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AdminSectionHeader(
            badge: 'Revue admin',
            title: 'Vidéos à valider',
            subtitle:
                'Validez uniquement les vidéos utiles aux clubs et aux recruteurs. Un refus supprime les fichiers et notifie le joueur.',
          ),
          SizedBox(height: spacing),
          const AdminInfoBanner(
            title: 'Contrôle avant publication',
            message:
                "Les joueurs peuvent soumettre leurs vidéos, mais aucune nouvelle vidéo ne devient publique sans validation admin.",
            icon: Icons.fact_check_outlined,
            tone: AdminBannerTone.warning,
          ),
          Padding(
            padding: EdgeInsets.symmetric(vertical: compact ? 10 : 12),
            child: AdminSearchField(
              controller: _searchController,
              maxWidth: 640,
              hintText: 'Rechercher par titre, ID ou joueur',
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
            final pendingVideos =
                allVideos.where((video) => video.isPendingReview).toList();
            final readyForDecision =
                pendingVideos.where((video) => video.optimized).length;
            final processingCount = pendingVideos.length - readyForDecision;
            final publishedCount =
                allVideos.where((video) => video.isApprovedPublic).length;

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
            final displayedVideos =
                filteredVideos.sublist(startIndex, endIndex);

            return Column(
              children: [
                Wrap(
                  spacing: compact ? 10 : 12,
                  runSpacing: compact ? 10 : 12,
                  children: [
                    AdminMiniStat(
                      label: 'En attente',
                      value: '${pendingVideos.length}',
                      icon: Icons.pending_actions_rounded,
                      accentColor: AdminTheme.warning,
                      subtitle: 'À traiter',
                      minWidth: compact ? 180 : 220,
                    ),
                    AdminMiniStat(
                      label: 'Prêtes',
                      value: '$readyForDecision',
                      icon: Icons.verified_outlined,
                      accentColor: AdminTheme.success,
                      subtitle: 'Décision possible',
                      minWidth: compact ? 180 : 220,
                    ),
                    AdminMiniStat(
                      label: 'Optimisation',
                      value: '$processingCount',
                      icon: Icons.autorenew_rounded,
                      accentColor: AdminTheme.cyan,
                      subtitle: 'En traitement',
                      minWidth: compact ? 180 : 220,
                    ),
                    AdminMiniStat(
                      label: 'Publiques',
                      value: '$publishedCount',
                      icon: Icons.public_rounded,
                      accentColor: AdminTheme.accent,
                      subtitle: 'Catalogue visible',
                      minWidth: compact ? 180 : 220,
                    ),
                  ],
                ),
                SizedBox(height: spacing),
                if (filteredVideos.isEmpty)
                  AdminEmptyState(
                    title: 'Aucune vidéo en attente',
                    message: searchQuery.trim().isEmpty
                        ? 'La file de revue est vide.'
                        : 'Aucune vidéo en attente ne correspond à cette recherche.',
                    icon: Icons.task_alt_rounded,
                    actionLabel: searchQuery.trim().isEmpty
                        ? 'Recharger la file'
                        : 'Effacer la recherche',
                    actionIcon: searchQuery.trim().isEmpty
                        ? Icons.refresh_rounded
                        : Icons.filter_alt_off_rounded,
                    onAction: () {
                      if (searchQuery.trim().isEmpty) {
                        videoController.fetchVideos();
                      } else {
                        setState(() {
                          searchQuery = '';
                          currentPage = 0;
                          _searchController.clear();
                        });
                      }
                    },
                  )
                else ...[
                  AdminDataTableCard(
                    compact: compact,
                    child: DataTable(
                      columnSpacing: tableColumnSpacing,
                      horizontalMargin: compact ? 10 : 12,
                      columns: const [
                        DataColumn(label: Text('Aperçu')),
                        DataColumn(label: Text('Contenu')),
                        DataColumn(label: Text('Joueur')),
                        DataColumn(label: Text('État')),
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
                                  label: _statusLabel(video),
                                  icon: video.optimized
                                      ? Icons.verified_outlined
                                      : Icons.autorenew_rounded,
                                  color: _statusColor(video),
                                ),
                              ),
                              DataCell(_buildActions(video)),
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
              ],
            );
          }),
        ],
      ),
    );
  }
}
