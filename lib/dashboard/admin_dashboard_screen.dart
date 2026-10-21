import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../config/app_routes.dart';
import '../controller/auth_controller.dart';
import '../controller/user_controller.dart';
import '../controller/video_controller.dart';
import '../theme/admin_theme.dart';
import '../theme/admin_type.dart';
import '../widgets/admin_page.dart';
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

  // Source unique pour app_routes.dart (resolveDashboardInitialIndex) :
  // sans ça, le nombre d'onglets restait dupliqué en dur dans les deux
  // fichiers, avec un risque de divergence silencieuse si un onglet est
  // ajouté ou retiré ici sans mettre à jour l'autre fichier.
  static final int tabCount = _AdminDashboardScreenState._dashboardItems.length;

  final AuthController authController = Get.find<AuthController>();
  final UserController userController = Get.find<UserController>();
  final VideoController videoController = Get.find<VideoController>();

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  // Un retrait de claim admin en cours de session (révocation par un autre
  // opérateur) ne doit pas laisser l'UI afficher des actions sensibles plus
  // longtemps que nécessaire : on revalide périodiquement, avec le même
  // contrôle (et la même déconnexion automatique en cas d'échec) qu'à
  // l'ouverture du tableau de bord.
  static const Duration _sessionRevalidationInterval = Duration(minutes: 5);

  static const double _railWidth = 232;
  static const double _railWidthCollapsed = 56;

  late int _selectedIndex;
  bool _isAuthorizing = true;
  Timer? _sessionRevalidationTimer;

  static const List<_DashboardItem> _dashboardItems = [
    _DashboardItem(
      title: 'Utilisateurs',
      subtitle: 'Gestion complète des profils, rôles et statuts.',
      icon: Icons.groups_rounded,
    ),
    _DashboardItem(
      title: 'Comptes administrés',
      subtitle:
          "Provisionnement et suivi des comptes créés par l’administration.",
      icon: Icons.manage_accounts_rounded,
    ),
    _DashboardItem(
      title: 'Vidéos à valider',
      subtitle: 'Validation avant publication publique.',
      icon: Icons.fact_check_rounded,
    ),
    _DashboardItem(
      title: 'Vidéos ajoutées',
      subtitle: 'Lecture, tri et modération du catalogue vidéo.',
      icon: Icons.play_circle_outline_rounded,
    ),
    _DashboardItem(
      title: 'Vidéos signalées',
      subtitle: 'Traitement prioritaire des contenus remontés.',
      icon: Icons.report_gmailerrorred_rounded,
    ),
    _DashboardItem(
      title: 'Offres',
      subtitle: 'Suivi des offres, statuts et candidatures.',
      icon: Icons.work_outline_rounded,
    ),
    _DashboardItem(
      title: 'Événements',
      subtitle: 'Suivi des événements, statuts et participants.',
      icon: Icons.event_note_rounded,
    ),
    _DashboardItem(
      title: 'Mise en relation',
      subtitle: 'Suivi des premiers contacts qualifiés.',
      icon: Icons.support_agent_rounded,
    ),
    _DashboardItem(
      title: 'Statistiques',
      subtitle: "Lecture visuelle de l’activité et des ratios du portail.",
      icon: Icons.insights_rounded,
    ),
  ];

  // Neuf entrées à plat, c'était une liste à relire à chaque fois. Les
  // regrouper par métier donne quatre blocs qu'on repère d'un coup d'oeil.
  // Les index pointent vers _dashboardItems : l'ordre des onglets et les
  // liens profonds de app_routes.dart restent inchangés.
  static const List<_DashboardGroup> _dashboardGroups = [
    _DashboardGroup(label: 'Communauté', indices: [0, 1]),
    _DashboardGroup(label: 'Modération', indices: [2, 3, 4]),
    _DashboardGroup(label: 'Activité', indices: [5, 6, 7]),
    _DashboardGroup(label: 'Analyse', indices: [8]),
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
  }

  @override
  void dispose() {
    _sessionRevalidationTimer?.cancel();
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
      signOutOnFailure: true,
    );

    if (!mounted) {
      return;
    }

    if (!accessResult.isAuthorized) {
      Get.snackbar('Accès refusé', accessResult.message ?? 'Accès refusé.');
      Get.offAllNamed(AppRoutes.adminLogin);
      return;
    }

    setState(() {
      _isAuthorizing = false;
    });

    _sessionRevalidationTimer?.cancel();
    _sessionRevalidationTimer = Timer.periodic(
      _sessionRevalidationInterval,
      (_) => _revalidateSessionInBackground(),
    );
  }

  Future<void> _revalidateSessionInBackground() async {
    if (widget.previewMode) {
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
      _sessionRevalidationTimer?.cancel();
      Get.snackbar(
        'Session révoquée',
        accessResult.message ??
            'Vos droits admin ont été retirés. Reconnectez-vous.',
      );
      Get.offAllNamed(AppRoutes.adminLogin);
    }
  }

  Future<void> _signOut() async {
    await widget.authController.signOut();
    Get.offAllNamed(AppRoutes.adminLogin);
  }

  Widget _buildNavTile({
    required int index,
    required bool expanded,
    required VoidCallback onTap,
  }) {
    final item = _dashboardItems[index];
    final selected = index == _selectedIndex;

    final tile = _NavTile(
      icon: item.icon,
      label: item.title,
      expanded: expanded,
      selected: selected,
      onTap: onTap,
    );

    if (expanded) {
      return tile;
    }

    return Tooltip(message: item.title, child: tile);
  }

  Widget _buildNavList({required bool expanded}) {
    final children = <Widget>[];

    for (final group in _dashboardGroups) {
      if (expanded) {
        children.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AdminTheme.space3,
              AdminTheme.space4,
              AdminTheme.space3,
              AdminTheme.space1 + 2,
            ),
            child: Text(group.label.toUpperCase(), style: AdminType.overline),
          ),
        );
      } else if (children.isNotEmpty) {
        children.add(
          const Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AdminTheme.space3,
              vertical: AdminTheme.space2,
            ),
            child: Divider(height: 1),
          ),
        );
      }

      for (final index in group.indices) {
        children.add(
          _buildNavTile(
            index: index,
            expanded: expanded,
            onTap: () => _onItemTapped(index),
          ),
        );
      }
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: AdminTheme.space3),
      children: children,
    );
  }

  Widget _buildBrand({required bool expanded}) {
    if (!expanded) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AdminTheme.space4),
        child: Center(child: AdminBrandMark(size: 30)),
      );
    }

    return const Padding(
      padding: EdgeInsets.fromLTRB(
        AdminTheme.space3,
        AdminTheme.space4,
        AdminTheme.space3,
        AdminTheme.space4,
      ),
      child: Row(
        children: [
          AdminBrandMark(size: 30),
          SizedBox(width: AdminTheme.space3),
          Expanded(child: Text('Adfoot', style: AdminType.brand)),
        ],
      ),
    );
  }

  /// Pied du rail : l'identité de la session et la déconnexion.
  ///
  /// La déconnexion était auparavant un bouton vert plein répété en haut
  /// de chaque écran. Elle appartient au compte, pas à la page.
  Widget _buildSessionFooter({required bool expanded}) {
    return Obx(() {
      final adminUser = widget.userController.user;
      final claimCount = widget.userController.grantedAdminClaims.length;
      final name = widget.previewMode
          ? 'Revue locale'
          : (adminUser?.nom.isNotEmpty == true
                ? adminUser!.nom
                : 'Compte admin');
      final detail = widget.previewMode
          ? 'Prévisualisation'
          : '$claimCount droit(s) validés';

      final menu = PopupMenuButton<String>(
        tooltip: 'Compte',
        position: PopupMenuPosition.over,
        offset: const Offset(0, -8),
        onSelected: (value) {
          if (value == 'signOut') {
            _signOut();
          }
        },
        itemBuilder: (context) => [
          PopupMenuItem<String>(
            value: 'signOut',
            height: 36,
            child: Row(
              children: const [
                Icon(
                  Icons.logout_rounded,
                  size: 16,
                  color: AdminTheme.textMuted,
                ),
                SizedBox(width: AdminTheme.space3),
                Text('Déconnexion', style: AdminType.body),
              ],
            ),
          ),
        ],
        child: Container(
          padding: const EdgeInsets.all(AdminTheme.space2),
          decoration: BoxDecoration(
            color: AdminTheme.surfaceSunken,
            borderRadius: BorderRadius.circular(AdminTheme.radiusSm),
            border: Border.all(color: AdminTheme.border),
          ),
          child: expanded
              ? Row(
                  children: [
                    Icon(
                      widget.previewMode
                          ? Icons.visibility_outlined
                          : Icons.verified_user_outlined,
                      size: 16,
                      color: widget.previewMode
                          ? AdminTheme.warning
                          : AdminTheme.textMuted,
                    ),
                    const SizedBox(width: AdminTheme.space2),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AdminType.labelStrong,
                          ),
                          Text(
                            detail,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AdminType.caption,
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.unfold_more_rounded,
                      size: 14,
                      color: AdminTheme.textMuted,
                    ),
                  ],
                )
              : Icon(
                  widget.previewMode
                      ? Icons.visibility_outlined
                      : Icons.verified_user_outlined,
                  size: 16,
                  color: widget.previewMode
                      ? AdminTheme.warning
                      : AdminTheme.textMuted,
                ),
        ),
      );

      return Padding(
        padding: const EdgeInsets.all(AdminTheme.space2),
        child: expanded ? menu : Tooltip(message: name, child: menu),
      );
    });
  }

  Widget _buildRail({required bool expanded}) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(right: BorderSide(color: AdminTheme.border)),
      ),
      child: Column(
        children: [
          _buildBrand(expanded: expanded),
          Expanded(child: _buildNavList(expanded: expanded)),
          const Divider(height: 1),
          _buildSessionFooter(expanded: expanded),
        ],
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      width: 260,
      child: SafeArea(
        child: Column(
          children: [
            _buildBrand(expanded: true),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: AdminTheme.space3),
                children: [
                  for (final group in _dashboardGroups) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AdminTheme.space3,
                        AdminTheme.space4,
                        AdminTheme.space3,
                        AdminTheme.space1 + 2,
                      ),
                      child: Text(
                        group.label.toUpperCase(),
                        style: AdminType.overline,
                      ),
                    ),
                    for (final index in group.indices)
                      _NavTile(
                        icon: _dashboardItems[index].icon,
                        label: _dashboardItems[index].title,
                        expanded: true,
                        selected: index == _selectedIndex,
                        onTap: () {
                          Navigator.pop(context);
                          _onItemTapped(index);
                        },
                      ),
                  ],
                ],
              ),
            ),
            const Divider(height: 1),
            _buildSessionFooter(expanded: true),
          ],
        ),
      ),
    );
  }

  // Chaque onglet reste monté (filtres, pagination, écouteurs Firestore
  // conservés) : seul l'onglet sélectionné est visible, les autres sont
  // réduits à (0,0) par Visibility.
  Widget _buildDashboardBody() {
    final tabs = _widgetOptions();
    // StackFit.expand : un onglet qui rend directement un état vide ou un
    // état de chargement doit occuper toute la zone de contenu, sinon il
    // se tasse en haut à gauche au lieu d'être centré.
    return Stack(
      fit: StackFit.expand,
      children: [
        for (var index = 0; index < tabs.length; index++)
          Visibility(
            visible: index == _selectedIndex,
            maintainState: true,
            child: tabs[index],
          ),
      ],
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

    final compactShell =
        MediaQuery.sizeOf(context).width < AdminTheme.breakpointShellCompact;
    final currentItem = _dashboardItems[_selectedIndex];

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!compactShell) ...[
          AdminPageBar(
            title: currentItem.title,
            subtitle: currentItem.subtitle,
          ),
          const SizedBox(height: AdminTheme.space1),
        ],
        Expanded(child: _buildDashboardBody()),
      ],
    );

    return Scaffold(
      appBar: compactShell
          ? AppBar(
              titleSpacing: 0,
              title: Text(
                currentItem.title,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              shape: const Border(bottom: BorderSide(color: AdminTheme.border)),
            )
          : null,
      drawer: compactShell ? _buildDrawer(context) : null,
      body: AdminAppBackground(
        child: compactShell
            ? Padding(
                padding: const EdgeInsets.all(AdminTheme.space3),
                child: content,
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width:
                        MediaQuery.sizeOf(context).width >=
                            AdminTheme.breakpointExtendedRail
                        ? _railWidth
                        : _railWidthCollapsed,
                    child: _buildRail(
                      expanded:
                          MediaQuery.sizeOf(context).width >=
                          AdminTheme.breakpointExtendedRail,
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AdminTheme.space4,
                        AdminTheme.space2,
                        AdminTheme.space4,
                        AdminTheme.space4,
                      ),
                      child: content,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _NavTile extends StatefulWidget {
  const _NavTile({
    required this.icon,
    required this.label,
    required this.expanded,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool expanded;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_NavTile> createState() => _NavTileState();
}

class _NavTileState extends State<_NavTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.selected
        ? AdminTheme.textPrimary
        : AdminTheme.textSecondary;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: widget.expanded ? AdminTheme.space2 : AdminTheme.space1 + 2,
        vertical: 1,
      ),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: Container(
            height: 34,
            padding: EdgeInsets.symmetric(
              horizontal: widget.expanded ? AdminTheme.space2 + 2 : 0,
            ),
            decoration: BoxDecoration(
              color: widget.selected
                  ? AdminTheme.surfaceRaised
                  : _hovered
                  ? AdminTheme.surfaceSunken
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(AdminTheme.radiusSm),
            ),
            child: widget.expanded
                ? Row(
                    children: [
                      Icon(widget.icon, size: 16, color: color),
                      const SizedBox(width: AdminTheme.space3 - 2),
                      Expanded(
                        child: Text(
                          widget.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AdminType.body.copyWith(
                            color: color,
                            fontWeight: widget.selected
                                ? FontWeight.w600
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  )
                : Center(child: Icon(widget.icon, size: 17, color: color)),
          ),
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

class _DashboardGroup {
  const _DashboardGroup({required this.label, required this.indices});

  final String label;
  final List<int> indices;
}
