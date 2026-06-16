import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:show_talent/models/user.dart';
import 'package:show_talent/models/video.dart';
import 'package:show_talent/screens/video_player.dart';

import '../controller/video_controller.dart';
import '../controller/user_controller.dart';
import '../theme/admin_theme.dart';
import '../widgets/admin_feedback.dart';
import '../widgets/admin_ui.dart';

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

  @override
  Widget build(BuildContext context) {
    final compact = _isCompactLayout(context);
    final panelPadding = compact ? 16.0 : 22.0;
    final spacing = compact ? 12.0 : 16.0;
    final tableColumnSpacing = compact ? 16.0 : 24.0;
    final rowHeight = compact ? 62.0 : 68.0;

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
                'Les aperçus, auteurs et actions de lecture sont regroupés pour une modération rapide.',
            icon: Icons.video_collection_outlined,
            tone: AdminBannerTone.info,
          ),
          Padding(
            padding: EdgeInsets.symmetric(vertical: compact ? 10 : 12),
            child: AdminSearchField(
              controller: _searchController,
              maxWidth: 640,
              hintText: 'Rechercher par titre',
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
                video.status,
                video.moderationStatus,
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
                      subtitle: 'Lecture mobile',
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
                      DataColumn(label: Text('Titre')),
                      DataColumn(label: Text('Ajoutée par')),
                      DataColumn(label: Text('Statut')),
                      DataColumn(label: Text('Actions')),
                    ],
                    rows: List<DataRow>.generate(
                      displayedVideos.length,
                      (index) => DataRow(
                        cells: [
                          DataCell(
                            ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                width: compact ? 92 : 108,
                                height: compact ? 54 : 62,
                                color: AdminTheme.surfaceSoft,
                                child: Image.network(
                                  displayedVideos[index].thumbnail,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Icon(
                                      Icons.video_library_outlined,
                                      color: AdminTheme.accent,
                                      size: 32,
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              displayedVideos[index].displayTitle,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AdminTheme.textPrimary,
                              ),
                            ),
                          ),
                          DataCell(
                            Text(_resolveUserName(displayedVideos[index].uid)),
                          ),
                          DataCell(
                            AdminPill(
                              label: displayedVideos[index].moderationLabel,
                              icon: Icons.fact_check_outlined,
                              color: _statusColor(displayedVideos[index]),
                            ),
                          ),
                          DataCell(
                            _deletingVideoId == displayedVideos[index].id
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : PopupMenuButton<String>(
                                    tooltip: 'Actions vidéo',
                                    onSelected: (value) {
                                      if (value == 'view_video') {
                                        final video = displayedVideos[index];
                                        final videoUrl = video.effectiveUrl;
                                        if (videoUrl.isEmpty) {
                                          showAdminFeedback(
                                            title: 'Lecture indisponible',
                                            message:
                                                'Aucune source MP4 exploitable pour cette vidéo.',
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
                                      } else if (value == 'delete_video') {
                                        _confirmDelete(
                                          context,
                                          displayedVideos[index].id,
                                        );
                                      }
                                    },
                                    itemBuilder: (context) => const [
                                      PopupMenuItem(
                                        value: 'view_video',
                                        child: Row(
                                          children: [
                                            Icon(
                                                Icons
                                                    .play_circle_outline_rounded,
                                                size: 18,
                                                color: AdminTheme.cyan),
                                            SizedBox(width: 8),
                                            Text('Regarder la vidéo'),
                                          ],
                                        ),
                                      ),
                                      PopupMenuItem(
                                        value: 'delete_video',
                                        child: Row(
                                          children: [
                                            Icon(Icons.delete_outline_rounded,
                                                size: 18,
                                                color: AdminTheme.danger),
                                            SizedBox(width: 8),
                                            Text('Supprimer la vidéo'),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ],
                      ),
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
          title: const Text('Confirmation'),
          content:
              const Text('Êtes-vous sûr de vouloir supprimer cette vidéo ?'),
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
                    title: 'Succès',
                    message: 'Vidéo supprimée avec succès.',
                    tone: AdminBannerTone.success,
                    position: SnackPosition.BOTTOM,
                  );
                } catch (error) {
                  showAdminFeedback(
                    title: 'Erreur',
                    message: 'Suppression impossible : $error',
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
