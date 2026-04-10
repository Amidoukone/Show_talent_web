import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:show_talent/models/user.dart';
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
            estBloque: false,
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
                'Parcours des contenus publiés avec lecture rapide et suppression ciblée.',
          ),
          SizedBox(height: spacing),
          const AdminInfoBanner(
            title: 'Modération visuelle',
            message:
                'Cette vue centralise les aperçus, les auteurs et les actions de lecture ou suppression sans modifier le flux métier existant.',
            icon: Icons.video_collection_outlined,
            tone: AdminBannerTone.info,
          ),
          Padding(
            padding: EdgeInsets.symmetric(vertical: compact ? 10 : 12),
            child: AdminSearchField(
              controller: _searchController,
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
              return video.caption.toLowerCase().contains(searchQuery);
            }).toList();

            final totalPages = (filteredVideos.length / rowsPerPage).ceil();
            final startIndex = currentPage * rowsPerPage;
            final endIndex = (startIndex + rowsPerPage).clamp(
              0,
              filteredVideos.length,
            );
            final displayedVideos =
                filteredVideos.sublist(startIndex, endIndex);

            if (filteredVideos.isEmpty) {
              final hasSearch = searchQuery.trim().isNotEmpty;

              return AdminEmptyState(
                title: 'Aucune video disponible',
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
                      subtitle: 'Base complete',
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
                              displayedVideos[index].caption,
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
                                        Get.to(
                                          () => VideoPlayerScreen(
                                            videoUrl:
                                                displayedVideos[index].videoUrl,
                                            userId: displayedVideos[index].uid,
                                            videoId: displayedVideos[index].id,
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
                  currentPage: currentPage,
                  totalPages: totalPages,
                  onPrevious: currentPage > 0
                      ? () {
                          setState(() {
                            currentPage--;
                          });
                        }
                      : null,
                  onNext: currentPage < totalPages - 1
                      ? () {
                          setState(() {
                            currentPage++;
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
