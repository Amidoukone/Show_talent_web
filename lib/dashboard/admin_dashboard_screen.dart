import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../config/app_routes.dart';
import '../controller/auth_controller.dart';
import '../controller/contact_intake_controller.dart';
import '../controller/event_controller.dart';
import '../controller/offre_controller.dart';
import '../controller/user_controller.dart';
import '../controller/video_controller.dart';
import '../models/contact_intake.dart';
import '../models/event.dart';
import '../models/offre.dart';
import '../theme/admin_theme.dart';
import '../utils/account_role_policy.dart';
import '../widgets/admin_ui.dart';
import 'contact_intake_management_widget.dart';
import 'event_management_widget.dart';
import 'managed_accounts_widget.dart';
import 'offer_management_widget.dart';
import 'statistiques_screen.dart';
import 'user_management_widget.dart';
import 'video_added_widget.dart';
import 'video_reported_widget.dart';
import 'video_review_widget.dart';

class AdminDashboardScreen extends StatefulWidget {
  AdminDashboardScreen({
    super.key,
    this.previewMode = false,
    this.initialIndex = 0,
  });

  final bool previewMode;
  final int initialIndex;

  final AuthController authController = Get.find<AuthController>();
  final UserController userController = Get.find<UserController>();
  final VideoController videoController = Get.find<VideoController>();
  final OffreController offreController = Get.find<OffreController>();
  final EventController eventController = Get.find<EventController>();
  final ContactIntakeController contactIntakeController =
      Get.find<ContactIntakeController>();

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  late int _selectedIndex;
  bool _isAuthorizing = true;
  final ScrollController _mainScrollController = ScrollController();

  static const List<_DashboardItem> _dashboardItems = [
    _DashboardItem(
      title: 'Utilisateurs',
      subtitle: 'Gestion compl\u00e8te des profils, r\u00f4les et statuts.',
      icon: Icons.groups_rounded,
    ),
    _DashboardItem(
      title: 'Comptes administr\u00e9s',
      subtitle:
          "Provisionnement et suivi des comptes cr\u00e9\u00e9s par l'administration.",
      icon: Icons.manage_accounts_rounded,
    ),
    _DashboardItem(
      title: 'Vid\u00e9os \u00e0 valider',
      subtitle: 'Validation avant publication publique.',
      icon: Icons.fact_check_rounded,
    ),
    _DashboardItem(
      title: 'Vid\u00e9os ajout\u00e9es',
      subtitle: 'Lecture, tri et mod\u00e9ration du catalogue vid\u00e9o.',
      icon: Icons.play_circle_outline_rounded,
    ),
    _DashboardItem(
      title: 'Vid\u00e9os signal\u00e9es',
      subtitle: 'Traitement prioritaire des contenus remont\u00e9s.',
      icon: Icons.report_gmailerrorred_rounded,
    ),
    _DashboardItem(
      title: 'Offres',
      subtitle: 'Suivi des offres, statuts et candidatures.',
      icon: Icons.work_outline_rounded,
    ),
    _DashboardItem(
      title: '\u00c9v\u00e9nements',
      subtitle: 'Suivi des \u00e9v\u00e9nements, statuts et participants.',
      icon: Icons.event_note_rounded,
    ),
    _DashboardItem(
      title: 'Mise en relation',
      subtitle: 'Suivi des premiers contacts qualifi\u00e9s.',
      icon: Icons.support_agent_rounded,
    ),
    _DashboardItem(
      title: 'Statistiques',
      subtitle: "Lecture visuelle de l'activit\u00e9 et des ratios du portail.",
      icon: Icons.insights_rounded,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex.clamp(0, _dashboardItems.length - 1);
    _guardDashboardAccess();
  }

  List<Widget> _widgetOptions() {
    return [
      const UserManagementWidget(selectedRole: 'Tous'),
      const ManagedAccountsWidget(),
      const VideoReviewWidget(),
      const VideoAddedWidget(),
      const VideoReportedWidget(),
      const OfferManagementWidget(),
      const EventManagementWidget(),
      const ContactIntakeManagementWidget(),
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

    final accessResult = await widget.authController.validateCurrentSession(
      forceRefresh: true,
      signOutOnFailure: true,
    );

    if (!mounted) {
      return;
    }

    if (!accessResult.isAuthorized) {
      Get.snackbar(
        'Acc\u00e8s refus\u00e9',
        accessResult.message ?? 'Acc\u00e8s refus\u00e9.',
      );
      Get.offAllNamed(AppRoutes.adminLogin);
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
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: selected
            ? AdminTheme.accent
            : AdminTheme.surfaceSoft.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(12),
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
            padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
            child: extendedRail
                ? Row(
                    children: [
                      const AdminBrandMark(
                        size: 44,
                        width: 84,
                        label: 'ADFOOT',
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
                              'Espace admin',
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
                    child: const AdminBrandMark(
                      size: 50,
                      width: 74,
                      label: 'ADFOOT',
                    ),
                  ),
          ),
          Divider(
            color: AdminTheme.borderSoft.withValues(alpha: 0.6),
            indent: 12,
            endIndent: 12,
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(8, 10, 8, 16),
              itemCount: _dashboardItems.length,
              separatorBuilder: (_, _) => const SizedBox(height: 6),
              itemBuilder: (context, index) {
                final item = _dashboardItems[index];
                final selected = index == _selectedIndex;

                final navTile = Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: extendedRail ? 10 : 7,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
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
                      borderRadius: BorderRadius.circular(16),
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
              final claimCount =
                  widget.userController.grantedAdminClaims.length;

              return AdminGlassPanel(
                padding: const EdgeInsets.all(12),
                radius: 20,
                accentColor: AdminTheme.cyan,
                child: extendedRail
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AdminPill(
                            label: widget.previewMode
                                ? 'Pr\u00e9visualisation'
                                : 'Session',
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
                                ? 'Revue locale'
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
                                ? 'Navigation de contr\u00f4le'
                                : '$claimCount droit(s) valid\u00e9s',
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
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      highlight: true,
      accentColor: AdminTheme.cyan,
      child: LayoutBuilder(
        builder: (context, headerConstraints) {
          final stacked = headerConstraints.maxWidth < 840;

          final intro = AdminSectionHeader(
            badge: 'Espace actif',
            title: currentItem.title,
            subtitle: currentItem.subtitle,
          );

          final actions = Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed: () => Get.toNamed(AppRoutes.statistics),
                icon: const Icon(Icons.auto_graph_rounded),
                label: const Text('Vue statistiques'),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  await widget.authController.signOut();
                  Get.offAllNamed(AppRoutes.adminLogin);
                },
                icon: const Icon(Icons.logout_rounded),
                label: const Text('D\u00e9connexion'),
              ),
            ],
          );

          if (stacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [intro, const SizedBox(height: 16), actions],
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
      final offers = widget.offreController.offres;
      final events = widget.eventController.events;
      final contactIntakes = widget.contactIntakeController.contactIntakes;
      final managedCount = users
          .where(
            (user) => user.createdByAdmin || isManagedAccountRole(user.role),
          )
          .length;
      final reportedCount = widget.videoController.getReportedVideos().length;
      final authDisabledCount = users.where((user) => user.authDisabled).length;
      final openOffers = offers
          .where((offre) => Offre.normalizeStatus(offre.statut) == 'ouverte')
          .length;
      final openEvents = events
          .where((event) => Event.normalizeStatus(event.statut) == 'ouvert')
          .length;
      final newLeadCount = contactIntakes
          .where(
            (intake) =>
                AgencyFollowUpStatus.normalize(intake.agencyFollowUpStatus) ==
                AgencyFollowUpStatus.newLead,
          )
          .length;

      final totalUsers = users.length;
      final totalVideos = videos.length;
      final pendingVideos = videos
          .where((video) => video.isPendingReview)
          .length;
      final totalOffers = offers.length;
      final totalEvents = events.length;
      final totalContactIntakes = contactIntakes.length;

      final cards = [
        AdminMetricCard(
          title: 'Utilisateurs',
          value: '$totalUsers',
          subtitle: 'Profils du portail',
          icon: Icons.groups_2_rounded,
          progress: totalUsers == 0 ? 0 : 1,
        ),
        AdminMetricCard(
          title: 'Comptes administr\u00e9s',
          value: '$managedCount',
          subtitle: "Suivis par l'administration",
          icon: Icons.badge_rounded,
          progress: totalUsers == 0 ? 0 : managedCount / totalUsers,
          accentColor: AdminTheme.cyan,
        ),
        AdminMetricCard(
          title: 'Vid\u00e9os',
          value: '$totalVideos',
          subtitle: '$reportedCount signalements',
          icon: Icons.ondemand_video_rounded,
          progress: totalVideos == 0 ? 0 : 1,
          accentColor: AdminTheme.accentSoft,
        ),
        AdminMetricCard(
          title: '\u00c0 valider',
          value: '$pendingVideos',
          subtitle: 'Vid\u00e9os en revue admin',
          icon: Icons.fact_check_rounded,
          progress: totalVideos == 0 ? 0 : pendingVideos / totalVideos,
          accentColor: AdminTheme.warning,
        ),
        AdminMetricCard(
          title: 'Offres',
          value: '$totalOffers',
          subtitle: '$openOffers ouvertes',
          icon: Icons.work_outline_rounded,
          progress: totalOffers == 0 ? 0 : openOffers / totalOffers,
          accentColor: AdminTheme.cyan,
        ),
        AdminMetricCard(
          title: '\u00c9v\u00e9nements',
          value: '$totalEvents',
          subtitle: '$openEvents ouverts',
          icon: Icons.event_note_rounded,
          progress: totalEvents == 0 ? 0 : openEvents / totalEvents,
          accentColor: AdminTheme.success,
        ),
        AdminMetricCard(
          title: 'Acc\u00e8s suspendus',
          value: '$authDisabledCount',
          subtitle: 'Comptes temporairement bloqu\u00e9s',
          icon: Icons.lock_person_rounded,
          progress: totalUsers == 0 ? 0 : authDisabledCount / totalUsers,
          accentColor: AdminTheme.warning,
        ),
        AdminMetricCard(
          title: 'Mises en relation',
          value: '$totalContactIntakes',
          subtitle: '$newLeadCount nouveau(x) lead(s)',
          icon: Icons.support_agent_rounded,
          progress: totalContactIntakes == 0
              ? 0
              : newLeadCount / totalContactIntakes,
          accentColor: AdminTheme.accentSoft,
        ),
      ];

      return LayoutBuilder(
        builder: (context, constraints) {
          final mobileMetrics = constraints.maxWidth < 640;
          const spacing = 12.0;

          if (mobileMetrics) {
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: cards
                    .map(
                      (card) => Padding(
                        padding: const EdgeInsets.only(right: spacing),
                        child: SizedBox(width: 236, child: card),
                      ),
                    )
                    .toList(),
              ),
            );
          }

          final columns = constraints.maxWidth >= 1240
              ? 4
              : constraints.maxWidth >= 880
              ? 3
              : 2;
          final availableWidth =
              constraints.maxWidth - (spacing * (columns - 1));
          final cardWidth = availableWidth / columns;

          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: cards
                .map((card) => SizedBox(width: cardWidth, child: card))
                .toList(),
          );
        },
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
                  color: selected
                      ? AdminTheme.background
                      : AdminTheme.textSecondary,
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
                  color: selected
                      ? AdminTheme.background
                      : AdminTheme.textPrimary,
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
            padding: const EdgeInsets.only(right: 2, bottom: 8),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: mainConstraints.maxHeight),
              child: AdminContentFrame(
                maxWidth: compactLayout
                    ? AdminTheme.readingMaxWidth
                    : AdminTheme.contentMaxWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildDashboardHeader(currentItem),
                    const SizedBox(height: 16),
                    if (compactLayout) ...[
                      _buildCompactNavigation(),
                      const SizedBox(height: 16),
                    ],
                    _buildDashboardMetrics(compact: compactLayout),
                    const SizedBox(height: 16),
                    _buildDashboardBody(),
                  ],
                ),
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
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return Scaffold(
      body: AdminAppBackground(
        padding: EdgeInsets.all(
          MediaQuery.sizeOf(context).width < 1160 ? 16 : 18,
        ),
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
                  width: extendedRail ? 284 : 96,
                  child: _buildSidebar(extendedRail),
                ),
                const SizedBox(width: 16),
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
