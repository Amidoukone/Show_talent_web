import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controller/user_controller.dart';
import '../controller/video_controller.dart';
import '../theme/admin_theme.dart';
import '../utils/account_role_policy.dart';
import '../widgets/admin_ui.dart';
import 'blocked_users_widget.dart';
import 'managed_accounts_widget.dart';
import 'statistiques_screen.dart';
import 'user_management_widget.dart';
import 'video_added_widget.dart';
import 'video_reported_widget.dart';

class AdminDashboardScreen extends StatefulWidget {
  AdminDashboardScreen({super.key, this.previewMode = false});

  final bool previewMode;

  final UserController userController = Get.find<UserController>();
  final VideoController videoController = Get.find<VideoController>();

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _selectedIndex = 0;
  bool _isAuthorizing = true;
  final ScrollController _mainScrollController = ScrollController();

  static const List<_DashboardItem> _dashboardItems = [
    _DashboardItem(
      title: 'Utilisateurs',
      subtitle: 'Gestion complete des profils, roles et statuts.',
      icon: Icons.groups_rounded,
    ),
    _DashboardItem(
      title: 'Comptes geres',
      subtitle: 'Provisionnement et suivi des comptes administres.',
      icon: Icons.manage_accounts_rounded,
    ),
    _DashboardItem(
      title: 'Videos ajoutees',
      subtitle: 'Lecture, tri et moderation du catalogue video.',
      icon: Icons.play_circle_outline_rounded,
    ),
    _DashboardItem(
      title: 'Videos signalees',
      subtitle: 'Traitement prioritaire des contenus remontes.',
      icon: Icons.report_gmailerrorred_rounded,
    ),
    _DashboardItem(
      title: 'Utilisateurs bloques',
      subtitle: 'Deblocage, statut Auth et revue des comptes restrints.',
      icon: Icons.block_rounded,
    ),
    _DashboardItem(
      title: 'Statistiques',
      subtitle: 'Lecture visuelle de l activite et des ratios du portail.',
      icon: Icons.insights_rounded,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _guardDashboardAccess();
  }

  List<Widget> _widgetOptions() {
    return [
      const UserManagementWidget(selectedRole: 'Tous'),
      const ManagedAccountsWidget(),
      const VideoAddedWidget(),
      const VideoReportedWidget(),
      const BlockedUsersWidget(),
      StatisticsOverviewPanel(
        userController: widget.userController,
        videoController: widget.videoController,
      ),
    ];
  }

  void _onItemTapped(int index) {
    if (_selectedIndex == index) {
      return;
    }

    setState(() {
      _selectedIndex = index;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_mainScrollController.hasClients) {
        _mainScrollController.jumpTo(0);
      }
    });
  }

  @override
  void dispose() {
    _mainScrollController.dispose();
    super.dispose();
  }

  Future<void> _guardDashboardAccess() async {
    if (widget.previewMode) {
      setState(() {
        _isAuthorizing = false;
      });
      return;
    }

    final accessResult = await widget.userController.evaluateAdminAccess(
      forceRefresh: true,
    );

    if (!mounted) {
      return;
    }

    if (!accessResult.isAuthorized) {
      Get.snackbar('Acces refuse', accessResult.message ?? 'Acces refuse.');
      await widget.userController.signOut();
      return;
    }

    setState(() {
      _isAuthorizing = false;
    });
  }

  Widget _buildSidebarIconBubble({
    required IconData icon,
    required bool selected,
  }) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: selected
            ? AdminTheme.accent
            : AdminTheme.surfaceSoft.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: selected
              ? AdminTheme.accentSoft.withValues(alpha: 0.36)
              : AdminTheme.border.withValues(alpha: 0.72),
        ),
      ),
      child: Icon(
        icon,
        color: selected ? AdminTheme.background : AdminTheme.textSecondary,
        size: 20,
      ),
    );
  }

  Widget _buildSidebar(bool extendedRail) {
    return AdminGlassPanel(
      padding: EdgeInsets.zero,
      highlight: true,
      accentColor: AdminTheme.accent,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 18, 14, 14),
            child: extendedRail
                ? Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: AdminTheme.surfaceSoft.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: AdminTheme.accent.withValues(alpha: 0.2),
                          ),
                        ),
                        padding: const EdgeInsets.all(10),
                        child: Image.asset('assets/logo.png'),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Adfoot',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: AdminTheme.textPrimary,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Admin workspace',
                              style: TextStyle(
                                color: AdminTheme.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : Center(
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: AdminTheme.surfaceSoft.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AdminTheme.accent.withValues(alpha: 0.2),
                        ),
                      ),
                      padding: const EdgeInsets.all(10),
                      child: Image.asset('assets/logo.png'),
                    ),
                  ),
          ),
          Divider(
            color: AdminTheme.borderSoft.withValues(alpha: 0.6),
            indent: 14,
            endIndent: 14,
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 16),
              itemCount: _dashboardItems.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = _dashboardItems[index];
                final selected = index == _selectedIndex;

                final navTile = Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: extendedRail ? 10 : 8,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: selected
                          ? AdminTheme.accent.withValues(alpha: 0.34)
                          : AdminTheme.borderSoft.withValues(alpha: 0.68),
                    ),
                    gradient: selected
                        ? LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AdminTheme.accent.withValues(alpha: 0.28),
                              AdminTheme.cyan.withValues(alpha: 0.12),
                            ],
                          )
                        : null,
                    color: selected
                        ? null
                        : AdminTheme.surface.withValues(alpha: 0.22),
                  ),
                  child: extendedRail
                      ? Row(
                          children: [
                            _buildSidebarIconBubble(
                              icon: item.icon,
                              selected: selected,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: selected
                                          ? AdminTheme.textPrimary
                                          : AdminTheme.textSecondary,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    item.subtitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: selected
                                          ? AdminTheme.accentSoft
                                          : AdminTheme.textMuted,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      : Center(
                          child: _buildSidebarIconBubble(
                            icon: item.icon,
                            selected: selected,
                          ),
                        ),
                );

                return Tooltip(
                  message: item.title,
                  waitDuration: const Duration(milliseconds: 350),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () => _onItemTapped(index),
                      child: navTile,
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            child: Obx(() {
              final adminUser = widget.userController.user;
              final claimCount = widget.userController.grantedAdminClaims.length;

              return AdminGlassPanel(
                padding: const EdgeInsets.all(12),
                radius: 20,
                accentColor: AdminTheme.cyan,
                child: extendedRail
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AdminPill(
                            label:
                                widget.previewMode ? 'Apercu local' : 'Session',
                            icon: widget.previewMode
                                ? Icons.visibility_outlined
                                : Icons.verified_user_outlined,
                            color: widget.previewMode
                                ? AdminTheme.warning
                                : AdminTheme.cyan,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            widget.previewMode
                                ? 'Mode design'
                                : adminUser?.nom.isNotEmpty == true
                                    ? adminUser!.nom
                                    : 'Compte admin',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AdminTheme.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.previewMode
                                ? 'Sans verification distante'
                                : '$claimCount claim(s) valides',
                            style: const TextStyle(
                              color: AdminTheme.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      )
                    : const Center(
                        child: Icon(
                          Icons.verified_user_outlined,
                          color: AdminTheme.cyan,
                        ),
                      ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardHeader(_DashboardItem currentItem) {
    return AdminGlassPanel(
      padding: const EdgeInsets.all(22),
      highlight: true,
      accentColor: AdminTheme.cyan,
      child: LayoutBuilder(
        builder: (context, headerConstraints) {
          final stacked = headerConstraints.maxWidth < 840;

          final intro = AdminSectionHeader(
            badge: 'Live workspace',
            title: currentItem.title,
            subtitle: currentItem.subtitle,
          );

          final actions = Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const AdminPill(
                label: 'Theme uniformise',
                icon: Icons.palette_outlined,
                color: AdminTheme.cyan,
              ),
              OutlinedButton.icon(
                onPressed: () => Get.toNamed('/statistics'),
                icon: const Icon(Icons.auto_graph_rounded),
                label: const Text('Vue stats'),
              ),
              ElevatedButton.icon(
                onPressed: () => widget.userController.signOut(),
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Deconnexion'),
              ),
            ],
          );

          if (stacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                intro,
                const SizedBox(height: 16),
                actions,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: intro),
              const SizedBox(width: 14),
              actions,
            ],
          );
        },
      ),
    );
  }

  Widget _buildDashboardMetrics({required bool compact}) {
    return Obx(() {
      final users = widget.userController.userList;
      final videos = widget.videoController.videoList;
      final managedCount = users
          .where(
            (user) =>
                user.createdByAdmin || managedAccountRoles.contains(user.role),
          )
          .length;
      final reportedCount = widget.videoController.getReportedVideos().length;
      final blockedCount = users.where((user) => user.estBloque).length;

      final totalUsers = users.length;
      final totalVideos = videos.length;

      final cards = [
        AdminMetricCard(
          title: 'Utilisateurs',
          value: '$totalUsers',
          subtitle: 'Base suivie dans le portail',
          icon: Icons.groups_2_rounded,
          progress: totalUsers == 0 ? 0 : 1,
        ),
        AdminMetricCard(
          title: 'Comptes geres',
          value: '$managedCount',
          subtitle: 'Provisionnes cote admin',
          icon: Icons.badge_rounded,
          progress: totalUsers == 0 ? 0 : managedCount / totalUsers,
          accentColor: AdminTheme.cyan,
        ),
        AdminMetricCard(
          title: 'Videos',
          value: '$totalVideos',
          subtitle: '$reportedCount remontees',
          icon: Icons.ondemand_video_rounded,
          progress: totalVideos == 0 ? 0 : 1,
          accentColor: AdminTheme.accentSoft,
        ),
        AdminMetricCard(
          title: 'Blocages',
          value: '$blockedCount',
          subtitle: 'Comptes a surveiller',
          icon: Icons.warning_amber_rounded,
          progress: totalUsers == 0 ? 0 : blockedCount / totalUsers,
          accentColor: AdminTheme.warning,
        ),
      ];

      if (compact) {
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: cards
              .map(
                (card) => SizedBox(
                  width: 248,
                  child: card,
                ),
              )
              .toList(),
        );
      }

      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: cards
              .map(
                (card) => Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: SizedBox(width: 266, child: card),
                ),
              )
              .toList(),
        ),
      );
    });
  }

  Widget _buildCompactNavigation() {
    return AdminGlassPanel(
      padding: const EdgeInsets.all(12),
      accentColor: AdminTheme.accentSoft,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(_dashboardItems.length, (index) {
            final item = _dashboardItems[index];
            final selected = index == _selectedIndex;

            return Padding(
              padding: const EdgeInsets.only(right: 10),
              child: ChoiceChip(
                label: Text(item.title),
                avatar: Icon(
                  item.icon,
                  size: 18,
                  color:
                      selected ? AdminTheme.background : AdminTheme.textSecondary,
                ),
                selected: selected,
                onSelected: (_) => _onItemTapped(index),
                showCheckmark: false,
                selectedColor: AdminTheme.accent.withValues(alpha: 0.86),
                backgroundColor: AdminTheme.surfaceSoft.withValues(alpha: 0.42),
                side: BorderSide(
                  color: selected
                      ? AdminTheme.accentSoft.withValues(alpha: 0.36)
                      : AdminTheme.border.withValues(alpha: 0.8),
                ),
                labelStyle: TextStyle(
                  color: selected ? AdminTheme.background : AdminTheme.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildDashboardBody() {
    return KeyedSubtree(
      key: ValueKey(_selectedIndex),
      child: _widgetOptions()[_selectedIndex],
    );
  }

  Widget _buildScrollableMainContent({
    required _DashboardItem currentItem,
    required bool compactLayout,
  }) {
    return LayoutBuilder(
      builder: (context, mainConstraints) {
        return Scrollbar(
          controller: _mainScrollController,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _mainScrollController,
            padding: const EdgeInsets.only(right: 4, bottom: 4),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: mainConstraints.maxHeight),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildDashboardHeader(currentItem),
                  const SizedBox(height: 14),
                  if (compactLayout) ...[
                    _buildCompactNavigation(),
                    const SizedBox(height: 14),
                  ],
                  _buildDashboardMetrics(compact: compactLayout),
                  const SizedBox(height: 14),
                  _buildDashboardBody(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isAuthorizing) {
      return const Scaffold(
        body: AdminAppBackground(
          child: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    return Scaffold(
      body: AdminAppBackground(
        padding: const EdgeInsets.all(18),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final currentItem = _dashboardItems[_selectedIndex];
            final compactLayout = constraints.maxWidth < 1160;

            if (compactLayout) {
              return _buildScrollableMainContent(
                currentItem: currentItem,
                compactLayout: true,
              );
            }

            final extendedRail = constraints.maxWidth >= 1420;

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: extendedRail ? 300 : 102,
                  child: _buildSidebar(extendedRail),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: _buildScrollableMainContent(
                    currentItem: currentItem,
                    compactLayout: false,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DashboardItem {
  const _DashboardItem({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;
}
