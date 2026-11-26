import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controller/contact_leak_controller.dart';
import '../controller/user_controller.dart';
import '../models/contact_leak_report.dart';
import '../theme/admin_theme.dart';
import '../theme/admin_type.dart';
import '../utils/admin_date_format.dart';
import '../utils/admin_pagination.dart';
import '../widgets/admin_detail_panel.dart';
import '../widgets/admin_page.dart';
import '../widgets/admin_table.dart';
import '../widgets/admin_ui.dart';

/// Les origines possibles d'un signalement.
enum _LeakView { all, offers, events, profiles }

/// Une ligne de la file, quelle que soit sa provenance.
///
/// Les deux sources n'ont ni la même collection ni la même forme — un
/// signalement d'offre est un document dédié, un signalement de profil est
/// deux champs sur `users/{uid}`. Les ramener à une seule ligne est le seul
/// moyen de les trier et de les paginer ensemble, et l'opérateur n'a pas à
/// connaître cette différence d'architecture pour faire son travail.
class _LeakRow {
  const _LeakRow({
    required this.key,
    required this.originLabel,
    required this.ownerUid,
    required this.fields,
    required this.values,
    required this.isProfile,
    this.knownName,
    this.documentId,
    this.flaggedAt,
    this.legacyOwnerBlockOnly = false,
  });

  final String key;
  final String originLabel;
  final String ownerUid;

  /// Le nom déjà porté par la source, quand elle en porte un.
  ///
  /// Un signalement de profil est lu sur `users/{uid}` : son nom vient avec,
  /// et aller le rechercher dans la fenêtre de comptes chargée serait à la
  /// fois inutile et faux — la fenêtre est plafonnée, donc un compte signalé
  /// hors fenêtre s'afficherait sous son identifiant alors que son nom était
  /// déjà là. Un signalement d'offre, lui, ne porte que l'identifiant de
  /// l'auteur.
  final String? knownName;

  final List<String> fields;

  /// Ce que le serveur a retiré (offre, événement) ou ce que le document
  /// interne porte encore (profil). Dans les deux cas : ce que l'auteur a
  /// voulu publier.
  final Map<String, dynamic> values;

  final bool isProfile;
  final String? documentId;
  final DateTime? flaggedAt;
  final bool legacyOwnerBlockOnly;
}

/// Les coordonnées retirées avant publication, enfin lisibles.
///
/// Le serveur retire les numéros et les adresses des champs libres d'un
/// profil, d'une offre et d'un événement, puis consigne ce qu'il a retiré.
/// Personne ne lisait ces traces.
///
/// **Écran de lecture seule, et c'est volontaire.**
/// `contact_leak_reports` est fermée en écriture à tout le monde, opérateur
/// compris : les déclencheurs écrivent par le SDK Admin, et une trace de
/// modération ne se retouche pas. Ce que l'opérateur décide ensuite — avertir,
/// suspendre le compte, supprimer l'annonce — se fait par les actions qui
/// existent déjà, sur les écrans qui les portent.
class ContactLeakReportsWidget extends StatefulWidget {
  const ContactLeakReportsWidget({
    super.key,
    this.controller,
    this.userController,
  });

  /// Injectables pour les tests, résolus depuis GetX en production.
  final ContactLeakController? controller;
  final UserController? userController;

  @override
  State<ContactLeakReportsWidget> createState() =>
      _ContactLeakReportsWidgetState();
}

class _ContactLeakReportsWidgetState extends State<ContactLeakReportsWidget> {
  static const int _rowsPerPage = 25;

  /// Largeur en deçà de laquelle le tableau défile horizontalement. Sert
  /// aussi à AdminWorkspace pour décider si la fiche tient à côté.
  static const double _tableMinWidth = 980;

  late final ContactLeakController _controller;
  late final UserController _userController;
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  _LeakView _view = _LeakView.all;
  int _currentPage = 0;
  String? _selectedKey;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? Get.find<ContactLeakController>();
    _userController = widget.userController ?? Get.find<UserController>();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _isCompactLayout(BuildContext context) =>
      MediaQuery.sizeOf(context).width < AdminTheme.breakpointCompact;

  void _clearFilters() {
    setState(() {
      _searchQuery = '';
      _view = _LeakView.all;
      _currentPage = 0;
      _searchController.clear();
    });
  }

  void _setView(_LeakView view) {
    setState(() {
      _view = view;
      _currentPage = 0;
    });
  }

  String _viewLabel(_LeakView view) {
    switch (view) {
      case _LeakView.all:
        return 'Toutes les origines';
      case _LeakView.offers:
        return 'Offres';
      case _LeakView.events:
        return 'Événements';
      case _LeakView.profiles:
        return 'Profils';
    }
  }

  /// Le nom d'un compte, ou son identifiant.
  ///
  /// Retombe sur l'identifiant plutôt que sur « Inconnu » : la fenêtre de
  /// comptes chargée est plafonnée, et un auteur hors fenêtre existe
  /// parfaitement.
  /// Le nom à afficher pour une ligne : celui qu'elle porte, sinon la
  /// résolution par la fenêtre de comptes.
  String _rowLabel(_LeakRow row) {
    final known = row.knownName?.trim() ?? '';
    if (known.isNotEmpty && known != 'Nom inconnu') return known;
    return _accountLabel(row.ownerUid);
  }

  /// `uid -> nom`, mémoïsé pour la durée d'une passe de construction.
  ///
  /// Invalidé au tout début de chaque reconstruction (voir l'`Obx` du
  /// `build`) : sans ce cache, [_accountLabel] rebalayait `userList` en
  /// entier pour chaque ligne de signalement ou de profil affichée.
  Map<String, String>? _accountNamesByUid;

  String _accountLabel(String uid) {
    if (uid.isEmpty) return 'Auteur inconnu';
    final names = _accountNamesByUid ??= {
      for (final user in _userController.userList) user.uid: user.nom,
    };
    final name = names[uid]?.trim();
    if (name != null && name.isNotEmpty && name != 'Nom inconnu') return name;
    return uid;
  }

  List<_LeakRow> _buildRows() {
    final rows = <_LeakRow>[
      for (final report in _controller.reports)
        _LeakRow(
          key: 'report:${report.id}',
          originLabel: report.collectionLabel,
          ownerUid: report.ownerUid,
          fields: report.fields,
          values: report.originals,
          isProfile: false,
          documentId: report.docId,
          flaggedAt: report.flaggedAt,
          legacyOwnerBlockOnly: report.isLegacyOwnerBlockOnly,
        ),
      for (final profile in _controller.profiles)
        _LeakRow(
          key: 'profile:${profile.uid}',
          originLabel: 'Profil',
          ownerUid: profile.uid,
          knownName: profile.nom,
          fields: profile.fields,
          values: profile.currentValues,
          isProfile: true,
        ),
    ];

    // Les signalements datés d'abord, du plus récent au plus ancien, puis les
    // profils : le serveur ne pose aucun horodatage sur un profil signalé, et
    // les mêler aux autres sous une date absente les enverrait tous en queue
    // sans raison lisible.
    rows.sort((a, b) {
      if (a.isProfile != b.isProfile) return a.isProfile ? 1 : -1;
      final left = a.flaggedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final right = b.flaggedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return right.compareTo(left);
    });
    return rows;
  }

  bool _matchesView(_LeakRow row) {
    switch (_view) {
      case _LeakView.all:
        return true;
      case _LeakView.offers:
        return row.originLabel == 'Offre';
      case _LeakView.events:
        return row.originLabel == 'Événement';
      case _LeakView.profiles:
        return row.isProfile;
    }
  }

  String _fieldsSummary(_LeakRow row) {
    if (row.fields.isEmpty) return 'Aucun champ consigné';
    return row.fields.map(describeLeakField).join(', ');
  }

  Widget _buildLeakCard(_LeakRow row) {
    return AdminDataCard(
      onTap: () => setState(() => _selectedKey = row.key),
      title: Text(_rowLabel(row), style: AdminType.bodyStrong),
      subtitle: Text(_fieldsSummary(row), style: AdminType.caption),
      trailing: AdminPill(
        label: row.originLabel,
        color: row.isProfile ? AdminTheme.cyan : AdminTheme.warning,
      ),
      fields: [
        AdminDataCardField(
          label: 'Signalé le',
          value: Text(
            row.flaggedAt == null
                ? 'Sans date'
                : formatAdminDateTime(row.flaggedAt!),
          ),
        ),
        AdminDataCardField(
          label: 'Champs',
          value: Text('${row.fields.length}'),
        ),
      ],
    );
  }

  Widget _buildDetailPanel(_LeakRow row, List<_LeakRow> queue) {
    final index = queue.indexWhere((item) => item.key == row.key);

    return AdminDetailPanel(
      title: _rowLabel(row),
      subtitle: row.originLabel,
      position: index < 0 ? null : '${index + 1} / ${queue.length}',
      onPrevious: index > 0
          ? () => setState(() => _selectedKey = queue[index - 1].key)
          : null,
      onNext: index >= 0 && index < queue.length - 1
          ? () => setState(() => _selectedKey = queue[index + 1].key)
          : null,
      onClose: () => setState(() => _selectedKey = null),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          AdminDetailSection(
            title: 'Signalement',
            children: [
              AdminDetailField(label: 'Origine', value: row.originLabel),
              AdminDetailField(
                label: 'Signalé le',
                value: row.flaggedAt == null
                    ? ''
                    : formatAdminDateTime(row.flaggedAt!),
              ),
              AdminDetailField(label: 'Auteur', value: row.ownerUid),
              AdminDetailField(
                label: row.isProfile ? 'Compte' : 'Document',
                value: row.documentId ?? row.ownerUid,
              ),
              if (row.legacyOwnerBlockOnly)
                const AdminDetailField(
                  label: 'Nature',
                  value:
                      'Reliquat d’un document ancien, pas une tentative : les '
                      'coordonnées y étaient recopiées avant qu’elles ne '
                      'déménagent dans le document privé.',
                  valueColor: AdminTheme.textMuted,
                ),
            ],
          ),
          AdminDetailSection(
            title: row.isProfile
                ? 'Ce que le profil porte encore'
                : 'Ce qui a été retiré',
            children: [
              if (row.fields.isEmpty)
                Text(
                  'Aucun champ consigné sur ce signalement.',
                  style: AdminType.prose.copyWith(color: AdminTheme.textMuted),
                )
              else
                for (final field in row.fields)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AdminTheme.space3),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          describeLeakField(field),
                          style: AdminType.labelStrong,
                        ),
                        const SizedBox(height: AdminTheme.space1),
                        SelectableText(
                          _formatValue(row.values[field]),
                          style: AdminType.prose.copyWith(
                            color: row.values.containsKey(field)
                                ? AdminTheme.textSecondary
                                : AdminTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
            ],
          ),
          AdminDetailSection(
            title: 'Ce que cet écran ne fait pas',
            children: [
              Text(
                'Un signalement ne se modifie pas et ne se referme pas : '
                'c’est une trace de modération, écrite par le serveur. '
                'Ce qu’il faut en faire se décide ailleurs — avertir l’auteur, '
                'suspendre son accès depuis la gestion des utilisateurs, ou '
                'supprimer l’annonce depuis son écran.\n\n'
                'Le texte ci-dessus n’a jamais été publié : il est montré ici '
                'parce que c’est la seule audience qu’un signalement ait.',
                style: AdminType.prose.copyWith(
                  color: AdminTheme.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatValue(Object? value) {
    if (value == null) return 'Valeur absente du document.';
    if (value is Map) {
      return value.entries
          .map((entry) => '${entry.key} : ${entry.value}')
          .join('\n');
    }
    if (value is List) return value.join(', ');
    final text = value.toString().trim();
    return text.isEmpty ? 'Champ vidé.' : text;
  }

  @override
  Widget build(BuildContext context) {
    final compact = _isCompactLayout(context);
    final hasFilters = _searchQuery.isNotEmpty || _view != _LeakView.all;

    final toolbar = AdminToolbar(
      flexes: const [3, 2],
      filters: [
        AdminSearchField(
          controller: _searchController,
          hintText: 'Rechercher un auteur, un champ ou un texte retiré',
          onChanged: (value) {
            setState(() {
              _searchQuery = value.trim().toLowerCase();
              _currentPage = 0;
            });
          },
        ),
        AdminFilterDropdown<_LeakView>(
          label: 'Origine',
          value: _view,
          items: _LeakView.values,
          labelBuilder: _viewLabel,
          onChanged: _setView,
        ),
      ],
      trailing: [
        IconButton(
          onPressed: hasFilters ? _clearFilters : null,
          icon: const Icon(Icons.filter_alt_off_rounded, size: 17),
          tooltip: 'Réinitialiser les filtres',
        ),
        IconButton(
          onPressed: _controller.refreshLeaks,
          icon: const Icon(Icons.refresh_rounded, size: 17),
          tooltip: 'Recharger',
        ),
      ],
    );

    return Obx(() {
      // Invalide le cache des noms de compte à chaque reconstruction : la
      // première consultation ci-dessous le reconstruit une fois, et toutes
      // les lignes de cette passe le réutilisent ensuite.
      _accountNamesByUid = null;

      if (_controller.isLoading.value) {
        return const AdminLoadingState(message: 'Chargement des signalements…');
      }

      final loadError = _controller.lastError.value;
      if (loadError.isNotEmpty) {
        return AdminEmptyState(
          title: 'Chargement incomplet',
          message: loadError,
          icon: Icons.error_outline_rounded,
          actionLabel: 'Réessayer',
          actionIcon: Icons.refresh_rounded,
          onAction: _controller.refreshLeaks,
        );
      }

      final allRows = _buildRows();
      final filtered = allRows.where((row) {
        if (!_matchesView(row)) return false;
        if (_searchQuery.isEmpty) return true;
        return [
          _rowLabel(row),
          row.ownerUid,
          row.documentId,
          row.originLabel,
          _fieldsSummary(row),
          ...row.values.values.map((value) => value?.toString()),
        ].whereType<String>().any(
          (value) => value.toLowerCase().contains(_searchQuery),
        );
      }).toList();

      final page = paginateAdminList(
        filtered: filtered,
        currentPage: _currentPage,
        rowsPerPage: _rowsPerPage,
      );
      final totalPages = page.totalPages;
      final safePage = page.safePage;
      final startIndex = page.startIndex;
      final endIndex = page.endIndex;
      final displayed = page.items;

      final offerCount = allRows
          .where((row) => row.originLabel == 'Offre')
          .length;
      final eventCount = allRows
          .where((row) => row.originLabel == 'Événement')
          .length;
      final profileCount = allRows.where((row) => row.isProfile).length;
      final legacyCount = allRows
          .where((row) => row.legacyOwnerBlockOnly)
          .length;

      final stats = AdminStatStrip(
        stats: [
          AdminStat(label: 'affichés', value: '${filtered.length}'),
          AdminStat(
            label: 'offres',
            value: '$offerCount',
            selected: _view == _LeakView.offers,
            onTap: () => _setView(
              _view == _LeakView.offers ? _LeakView.all : _LeakView.offers,
            ),
          ),
          AdminStat(
            label: 'événements',
            value: '$eventCount',
            selected: _view == _LeakView.events,
            onTap: () => _setView(
              _view == _LeakView.events ? _LeakView.all : _LeakView.events,
            ),
          ),
          AdminStat(
            label: 'profils',
            value: '$profileCount',
            selected: _view == _LeakView.profiles,
            onTap: () => _setView(
              _view == _LeakView.profiles ? _LeakView.all : _LeakView.profiles,
            ),
            tooltip:
                'Profils dont un champ libre a été nettoyé avant publication',
          ),
          AdminStat(
            label: 'reliquats anciens',
            value: '$legacyCount',
            tooltip:
                'Coordonnées recopiées dans un document écrit avant qu’elles '
                'ne déménagent : un nettoyage, pas une tentative',
          ),
        ],
      );

      // Les deux flux sont plafonnés sans « charger plus », par choix : un
      // signalement est une ligne par document nettoyé, et la file se vide à
      // mesure que la modération agit. Atteindre le plafond ne se corrige pas
      // en paginant — autant le dire que laisser croire que tout est là.
      final notice = _controller.truncated.value
          ? const AdminInfoBanner(
              title: 'Liste plafonnée',
              message:
                  'Le nombre de signalements atteint la limite de lecture de '
                  'cet écran. Les plus récents sont affichés ; traitez-les '
                  'avant de conclure sur le reste.',
              icon: Icons.layers_outlined,
              tone: AdminBannerTone.warning,
            )
          : null;

      final Widget body;
      if (filtered.isEmpty) {
        body = allRows.isEmpty
            ? AdminEmptyState(
                title: 'Aucun signalement',
                message:
                    'Aucune coordonnée n’a été retirée d’un profil, d’une '
                    'offre ou d’un événement.',
                icon: Icons.verified_user_outlined,
                actionLabel: 'Recharger',
                actionIcon: Icons.refresh_rounded,
                onAction: _controller.refreshLeaks,
              )
            : AdminEmptyState(
                title: 'Aucun signalement dans cette vue',
                message: 'Aucun signalement ne correspond aux filtres actuels.',
                icon: Icons.filter_alt_off_outlined,
                actionLabel: 'Réinitialiser',
                actionIcon: Icons.filter_alt_off_rounded,
                onAction: _clearFilters,
              );
      } else if (compact) {
        body = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final row in displayed) ...[
              _buildLeakCard(row),
              const SizedBox(height: AdminTheme.space2),
            ],
          ],
        );
      } else {
        body = AdminTable(
          minWidth: _tableMinWidth,
          columns: const [
            AdminColumn(label: 'Auteur', flex: 3),
            AdminColumn(label: 'Origine', width: 130),
            AdminColumn(
              label: 'Champs nettoyés',
              flex: 4,
              tooltip:
                  'Une clé pointée vient du bloc d’auteur recopié dans le '
                  'document, pas d’une saisie.',
            ),
            AdminColumn(label: 'Signalé le', width: 170),
          ],
          rowCount: displayed.length,
          rowKey: (index) => ValueKey(displayed[index].key),
          selectedRow: _selectedKey == null
              ? null
              : displayed.indexWhere((row) => row.key == _selectedKey),
          onRowTap: (index) =>
              setState(() => _selectedKey = displayed[index].key),
          cellsBuilder: (index) {
            final row = displayed[index];

            return [
              AdminCellIdentity(
                title: _rowLabel(row),
                subtitle: row.documentId ?? row.ownerUid,
              ),
              Text(
                row.originLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AdminType.label.copyWith(
                  color: row.isProfile ? AdminTheme.cyan : AdminTheme.warning,
                ),
              ),
              Text(
                _fieldsSummary(row),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                row.flaggedAt == null
                    ? 'Sans date'
                    : formatAdminDateTime(row.flaggedAt!),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ];
          },
        );
      }

      final selected = _selectedKey == null
          ? null
          : filtered.where((row) => row.key == _selectedKey).firstOrNull;

      return AdminWorkspace(
        compact: compact,
        bodyMinWidth: _tableMinWidth,
        toolbar: toolbar,
        notice: notice,
        stats: stats,
        body: body,
        detail: selected == null ? null : _buildDetailPanel(selected, filtered),
        footer: filtered.isEmpty
            ? null
            : AdminListFooter(
                rangeStart: startIndex + 1,
                rangeEnd: endIndex,
                filteredCount: filtered.length,
                currentPage: safePage,
                totalPages: totalPages,
                itemLabel: 'signalements',
                onPrevious: safePage > 0
                    ? () => setState(() => _currentPage = safePage - 1)
                    : null,
                onNext: safePage < totalPages - 1
                    ? () => setState(() => _currentPage = safePage + 1)
                    : null,
              ),
      );
    });
  }
}
