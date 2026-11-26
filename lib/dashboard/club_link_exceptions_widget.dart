import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controller/club_link_controller.dart';
import '../controller/user_controller.dart';
import '../models/player_club_link.dart';
import '../theme/admin_theme.dart';
import '../theme/admin_type.dart';
import '../utils/admin_date_format.dart';
import '../utils/admin_pagination.dart';
import '../widgets/admin_detail_panel.dart';
import '../widgets/admin_feedback.dart';
import '../widgets/admin_page.dart';
import '../widgets/admin_table.dart';
import '../widgets/admin_ui.dart';

/// Les vues de la file, dans l'ordre où elles se présentent.
enum _LinkView {
  /// Tout ce qui attend un arbitrage, les trois cas réunis.
  exceptions,

  /// Le joueur conteste le rattachement.
  contested,

  /// Affiliation signalée après une révocation d'habilitation.
  review,

  /// Deux rattachements en cours sur le même joueur.
  duplicates,

  /// Tous les rattachements en cours, exception ou non.
  all,
}

/// La file des exceptions du rattachement joueur-club.
///
/// Trois situations gèlent un rattachement en attendant une décision humaine,
/// et aucune ne se débloque toute seule : une contestation du joueur, une
/// affiliation signalée après le retrait de l'habilitation de son club, et
/// deux clubs qui déclarent le même joueur. Sans cet écran elles attendaient
/// indéfiniment, et le joueur n'avait aucune réponse.
///
/// **Une seule issue est offerte : clore.** C'est une contrainte du serveur et
/// non un manque d'interface — `confirmClubLink` exige `playerUid == uid`,
/// donc aucun callable ne permet de confirmer à la place du joueur, et c'est
/// volontaire. Un doublon se résout en closant le rattachement de trop, jamais
/// en validant l'autre d'office.
class ClubLinkExceptionsWidget extends StatefulWidget {
  const ClubLinkExceptionsWidget({
    super.key,
    this.controller,
    this.userController,
  });

  /// Injectables pour les tests, résolus depuis GetX en production.
  final ClubLinkController? controller;
  final UserController? userController;

  @override
  State<ClubLinkExceptionsWidget> createState() =>
      _ClubLinkExceptionsWidgetState();
}

class _ClubLinkExceptionsWidgetState extends State<ClubLinkExceptionsWidget> {
  static const int _rowsPerPage = 25;

  /// Largeur en deçà de laquelle le tableau défile horizontalement. Sert
  /// aussi à AdminWorkspace pour décider si la fiche tient à côté.
  static const double _tableMinWidth = 1020;

  late final ClubLinkController _controller;
  late final UserController _userController;
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  _LinkView _view = _LinkView.exceptions;
  int _currentPage = 0;
  String? _actionLinkId;
  String? _selectedLinkId;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? Get.find<ClubLinkController>();
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
      _view = _LinkView.exceptions;
      _currentPage = 0;
      _searchController.clear();
    });
  }

  void _setView(_LinkView view) {
    setState(() {
      _view = view;
      _currentPage = 0;
    });
  }

  String _viewLabel(_LinkView view) {
    switch (view) {
      case _LinkView.exceptions:
        return 'Exceptions à trancher';
      case _LinkView.contested:
        return 'Contestations';
      case _LinkView.review:
        return 'À réexaminer';
      case _LinkView.duplicates:
        return 'Doublons';
      case _LinkView.all:
        return 'Tous les rattachements en cours';
    }
  }

  /// `uid -> nom`, mémoïsé pour la durée d'une passe de construction.
  ///
  /// Invalidé au tout début de chaque reconstruction (voir l'`Obx` du
  /// `build`) : sans ce cache, chaque appel à [_accountLabel] rebalayait
  /// `userList` en entier, et le filtre de recherche l'appelle une fois par
  /// rattachement ouvert à chaque frappe — plusieurs centaines de
  /// rattachements multipliées par la liste des comptes chargés, recalculées
  /// à chaque caractère tapé.
  Map<String, String>? _accountNamesByUid;

  /// Le nom d'un compte, ou son identifiant.
  ///
  /// Retombe sur l'identifiant plutôt que sur « Inconnu » : la fenêtre de
  /// comptes chargée est plafonnée, et un joueur hors fenêtre existe
  /// parfaitement — l'annoncer inconnu ferait douter du dossier.
  String _accountLabel(String uid) {
    if (uid.isEmpty) return 'Identifiant absent';
    final names = _accountNamesByUid ??= {
      for (final user in _userController.userList) user.uid: user.nom,
    };
    final name = names[uid]?.trim();
    if (name != null && name.isNotEmpty && name != 'Nom inconnu') return name;
    return uid;
  }

  /// Le nom du club, celui figé sur le rattachement d'abord.
  ///
  /// `clubName` est recopié par le callable au moment de la déclaration, et
  /// c'est le nom sous lequel le joueur a accepté — ou refusé. Un club
  /// renommé depuis ne doit pas réécrire l'histoire du dossier.
  String _clubLabel(PlayerClubLink link) {
    final frozen = link.clubName.trim();
    return frozen.isNotEmpty ? frozen : _accountLabel(link.clubUid);
  }

  /// La raison pour laquelle ce rattachement attend un arbitrage, ou `null`.
  ///
  /// Un même dossier peut cumuler les trois. L'ordre de priorité suit ce que
  /// l'opérateur doit traiter en premier : la parole du joueur passe devant
  /// une formalité d'accord, et les deux passent devant un doublon, qui se
  /// tranche en lisant les deux rattachements.
  String? _exceptionLabel(PlayerClubLink link, Set<String> duplicates) {
    if (link.isContested) return 'Contestation';
    if (link.reviewRequired) return 'À réexaminer';
    if (duplicates.contains(link.playerUid)) return 'Doublon';
    return null;
  }

  Color _exceptionColor(String? label) {
    switch (label) {
      case 'Contestation':
        return AdminTheme.dangerText;
      case 'À réexaminer':
        return AdminTheme.warning;
      case 'Doublon':
        return AdminTheme.cyan;
      default:
        return AdminTheme.textMuted;
    }
  }

  bool _matchesView(PlayerClubLink link, Set<String> duplicates) {
    switch (_view) {
      case _LinkView.exceptions:
        return _exceptionLabel(link, duplicates) != null;
      case _LinkView.contested:
        return link.isContested;
      case _LinkView.review:
        return link.reviewRequired;
      case _LinkView.duplicates:
        return duplicates.contains(link.playerUid);
      case _LinkView.all:
        return true;
    }
  }

  /// Depuis combien de temps l'exception attend, en deux ou trois caractères.
  String _waitingLabel(PlayerClubLink link) {
    final raisedAt = link.exceptionRaisedAt;
    if (raisedAt == null) return 'inconnue';

    final waited = DateTime.now().difference(raisedAt);
    if (waited.inDays >= 1) return '${waited.inDays} j';
    if (waited.inHours >= 1) return '${waited.inHours} h';
    return '< 1 h';
  }

  Future<void> _confirmEndLink(PlayerClubLink link) async {
    final playerLabel = _accountLabel(link.playerUid);
    final clubLabel = _clubLabel(link);

    final confirmed = await confirmAdminDeletion(
      context: context,
      title: 'Clore le rattachement',
      confirmLabel: 'Clore',
      confirmIcon: Icons.link_off_rounded,
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Clore le rattachement de $playerLabel à $clubLabel ?',
              style: AdminType.bodyStrong,
            ),
            const SizedBox(height: AdminTheme.space3),
            Text(
              'Le rattachement passe en historique et la fiche du joueur perd '
              'son club actuel. Ses faits sportifs lui restent : son poste et '
              'sa nationalité ne changent pas parce qu’il a quitté un club.',
              style: AdminType.prose.copyWith(color: AdminTheme.textSecondary),
            ),
            const SizedBox(height: AdminTheme.space2),
            Text(
              'Rien n’est supprimé, et cette clôture ne valide pas l’autre '
              'rattachement d’un doublon : seul le joueur peut confirmer le '
              'sien.',
              style: AdminType.caption.copyWith(color: AdminTheme.textMuted),
            ),
          ],
        ),
      ),
    );

    if (!confirmed || !mounted) return;

    setState(() => _actionLinkId = link.id);

    final response = await _controller.endLink(link.id);

    if (!mounted) return;
    setState(() {
      _actionLinkId = null;
      if (response.success && _selectedLinkId == link.id) {
        _selectedLinkId = null;
      }
    });

    showAdminFeedback(
      title: response.success ? 'Rattachement clos' : 'Clôture impossible',
      message: response.success
          ? 'Le rattachement de $playerLabel à $clubLabel est clos et '
                'conservé en historique.'
          : (response.message.trim().isNotEmpty
                ? response.message
                : 'Clôture du rattachement impossible pour le moment.'),
      tone: response.success ? AdminBannerTone.success : AdminBannerTone.danger,
      position: SnackPosition.BOTTOM,
    );
  }

  AdminRowActions _buildRowActions(PlayerClubLink link) {
    return AdminRowActions(
      busy: _actionLinkId == link.id,
      busyLabel: 'Clôture…',
      primary: [
        AdminRowAction(
          icon: Icons.link_off_rounded,
          label: link.isOpen
              ? 'Clore le rattachement'
              : 'Rattachement déjà clos',
          color: AdminTheme.dangerText,
          onPressed: link.isOpen ? () => _confirmEndLink(link) : null,
        ),
      ],
    );
  }

  Widget _buildLinkCard(PlayerClubLink link, Set<String> duplicates) {
    final exception = _exceptionLabel(link, duplicates);

    return AdminDataCard(
      onTap: () => setState(() => _selectedLinkId = link.id),
      title: Text(_accountLabel(link.playerUid), style: AdminType.bodyStrong),
      subtitle: Text(_clubLabel(link), style: AdminType.caption),
      trailing: exception == null
          ? null
          : AdminPill(label: exception, color: _exceptionColor(exception)),
      fields: [
        AdminDataCardField(label: 'État', value: Text(link.statusLabel)),
        AdminDataCardField(label: 'Depuis', value: Text(_waitingLabel(link))),
        if (link.contestReason != null)
          AdminDataCardField(
            label: 'Motif du joueur',
            value: Text(link.contestReason!),
          ),
      ],
      actions: _buildRowActions(link),
    );
  }

  /// Les autres rattachements en cours du même joueur.
  ///
  /// Montrés dans la fiche parce qu'un doublon ne se tranche pas autrement :
  /// l'opérateur a besoin de voir les deux déclarations côte à côte pour
  /// décider laquelle est de trop.
  List<PlayerClubLink> _siblingLinks(PlayerClubLink link) {
    if (link.playerUid.isEmpty) return const <PlayerClubLink>[];
    return _controller.openLinks
        .where(
          (other) => other.playerUid == link.playerUid && other.id != link.id,
        )
        .toList(growable: false);
  }

  Widget _buildDetailPanel(PlayerClubLink link, List<PlayerClubLink> queue) {
    final index = queue.indexWhere((item) => item.id == link.id);
    final siblings = _siblingLinks(link);
    final declaredFacts = describeClubLinkFacts(link.declaredFacts);
    final confirmedFacts = describeClubLinkFacts(link.confirmedFacts);
    final corrections = describeClubLinkFacts(link.corrections);

    return AdminDetailPanel(
      title: _accountLabel(link.playerUid),
      subtitle: _clubLabel(link),
      position: index < 0 ? null : '${index + 1} / ${queue.length}',
      onPrevious: index > 0
          ? () => setState(() => _selectedLinkId = queue[index - 1].id)
          : null,
      onNext: index >= 0 && index < queue.length - 1
          ? () => setState(() => _selectedLinkId = queue[index + 1].id)
          : null,
      onClose: () => setState(() => _selectedLinkId = null),
      actions: [
        ElevatedButton(
          onPressed: _actionLinkId == link.id || !link.isOpen
              ? null
              : () => _confirmEndLink(link),
          child: const Text('Clore'),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          AdminDetailSection(
            title: 'Rattachement',
            children: [
              AdminDetailField(label: 'État', value: link.statusLabel),
              AdminDetailField(
                label: 'Déclaré le',
                value: link.declaredAt == null
                    ? ''
                    : formatAdminDateTime(link.declaredAt!),
              ),
              AdminDetailField(
                label: 'Confirmé le',
                value: link.confirmedAt == null
                    ? ''
                    : formatAdminDateTime(link.confirmedAt!),
              ),
              AdminDetailField(
                label: 'Contesté le',
                value: link.contestedAt == null
                    ? ''
                    : formatAdminDateTime(link.contestedAt!),
              ),
              AdminDetailField(
                label: 'Accord invoqué',
                value: link.declaredUnderAgreementRef ?? '',
              ),
              AdminDetailField(label: 'Identifiant', value: link.id),
            ],
          ),
          if (link.contestReason != null || link.isContested)
            AdminDetailSection(
              title: 'Contestation',
              children: [
                Text(
                  link.contestReason ??
                      'Le joueur a contesté sans écrire de motif.',
                  style: AdminType.prose.copyWith(
                    color: AdminTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: AdminTheme.space2),
                Text(
                  'Une contestation gèle l’état public : elle ne publie ni ne '
                  'dépublie. La seule issue dont ce portail dispose est de '
                  'clore — personne ne peut confirmer à la place du joueur.',
                  style: AdminType.caption.copyWith(
                    color: AdminTheme.textMuted,
                  ),
                ),
              ],
            ),
          if (link.reviewRequired)
            AdminDetailSection(
              title: 'Réexamen demandé',
              children: [
                AdminDetailField(
                  label: 'Motif',
                  value: link.reviewFollowsRevocation
                      ? 'Habilitation du club retirée'
                      : (link.reviewReason ?? 'Non précisé'),
                ),
                AdminDetailField(
                  label: 'Demandé le',
                  value: link.reviewRequestedAt == null
                      ? ''
                      : formatAdminDateTime(link.reviewRequestedAt!),
                ),
                AdminDetailField(
                  label: 'Motif du retrait',
                  value: link.revocationReason ?? '',
                ),
                Text(
                  'Le joueur a lu ce que son club déclarait et l’a accepté : '
                  'sa confirmation ne devient pas fausse parce que l’accord '
                  'de son club a été retiré. Ce que la révocation retire, '
                  'c’est la caution d’Adfoot sur cette provenance, pas le '
                  'fait lui-même.',
                  style: AdminType.prose.copyWith(
                    color: AdminTheme.textSecondary,
                  ),
                ),
              ],
            ),
          if (siblings.isNotEmpty)
            AdminDetailSection(
              title: 'Doublon : ${siblings.length} autre(s) rattachement(s)',
              children: [
                for (final sibling in siblings)
                  AdminDetailField(
                    label: _clubLabel(sibling),
                    value:
                        '${sibling.statusLabel}'
                        '${sibling.declaredAt == null ? '' : ' · déclaré le ${formatAdminDate(sibling.declaredAt!)}'}',
                  ),
                const SizedBox(height: AdminTheme.space2),
                Text(
                  'Un joueur n’a qu’un club à la fois. Clore celui de trop '
                  'suffit : l’autre reste tel qu’il est, et c’est au joueur de '
                  'le confirmer.',
                  style: AdminType.caption.copyWith(
                    color: AdminTheme.textMuted,
                  ),
                ),
              ],
            ),
          AdminDetailSection(
            title: 'Faits déclarés par le club',
            children: [
              SelectableText(
                declaredFacts.isEmpty
                    ? 'Le club n’a déclaré aucun fait sportif.'
                    : declaredFacts,
                style: AdminType.prose.copyWith(
                  color: declaredFacts.isEmpty
                      ? AdminTheme.textMuted
                      : AdminTheme.textSecondary,
                ),
              ),
            ],
          ),
          if (confirmedFacts.isNotEmpty || corrections.isNotEmpty)
            AdminDetailSection(
              title: 'Ce que le joueur a accepté',
              children: [
                SelectableText(
                  confirmedFacts.isEmpty
                      ? 'Aucun fait confirmé.'
                      : confirmedFacts,
                  style: AdminType.prose.copyWith(
                    color: AdminTheme.textSecondary,
                  ),
                ),
                if (corrections.isNotEmpty) ...[
                  const SizedBox(height: AdminTheme.space3),
                  Text('Corrections du joueur', style: AdminType.labelStrong),
                  const SizedBox(height: AdminTheme.space1),
                  SelectableText(
                    corrections,
                    style: AdminType.prose.copyWith(
                      color: AdminTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AdminTheme.space2),
                  Text(
                    'Une correction n’est pas un litige : le joueur reste le '
                    'dernier mot sur ce qui le concerne.',
                    style: AdminType.caption.copyWith(
                      color: AdminTheme.textMuted,
                    ),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final compact = _isCompactLayout(context);
    final hasFilters = _searchQuery.isNotEmpty || _view != _LinkView.exceptions;

    final toolbar = AdminToolbar(
      flexes: const [3, 2],
      filters: [
        AdminSearchField(
          controller: _searchController,
          hintText: 'Rechercher un joueur, un club ou un accord',
          onChanged: (value) {
            setState(() {
              _searchQuery = value.trim().toLowerCase();
              _currentPage = 0;
            });
          },
        ),
        AdminFilterDropdown<_LinkView>(
          label: 'Vue',
          value: _view,
          items: _LinkView.values,
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
          onPressed: _controller.refreshLinks,
          icon: const Icon(Icons.refresh_rounded, size: 17),
          tooltip: 'Recharger la file',
        ),
      ],
    );

    return Obx(() {
      // Invalide le cache des noms de compte à chaque reconstruction : la
      // première consultation ci-dessous (le filtre, en général) le
      // reconstruit une fois, et toutes les lignes de cette passe le
      // réutilisent ensuite.
      _accountNamesByUid = null;

      if (_controller.isLoading.value) {
        return const AdminLoadingState(
          message: 'Chargement des rattachements…',
        );
      }

      final loadError = _controller.lastError.value;
      if (loadError.isNotEmpty) {
        return AdminEmptyState(
          title: 'Chargement incomplet',
          message: loadError,
          icon: Icons.error_outline_rounded,
          actionLabel: 'Réessayer',
          actionIcon: Icons.refresh_rounded,
          onAction: _controller.refreshLinks,
        );
      }

      final allLinks = _controller.openLinks;
      final duplicates = _controller.duplicatedPlayerUids;

      final filtered = allLinks.where((link) {
        if (!_matchesView(link, duplicates)) return false;
        if (_searchQuery.isEmpty) return true;
        return [
          _accountLabel(link.playerUid),
          link.playerUid,
          _clubLabel(link),
          link.clubUid,
          link.declaredUnderAgreementRef,
          link.contestReason,
          link.statusLabel,
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

      final contestedCount = allLinks.where((link) => link.isContested).length;
      final reviewCount = allLinks.where((link) => link.reviewRequired).length;
      final duplicateCount = allLinks
          .where((link) => duplicates.contains(link.playerUid))
          .length;

      final stats = AdminStatStrip(
        stats: [
          AdminStat(label: 'affichés', value: '${filtered.length}'),
          AdminStat(
            label: 'contestations',
            value: '$contestedCount',
            tone: contestedCount > 0 ? AdminTheme.dangerText : null,
            selected: _view == _LinkView.contested,
            onTap: () => _setView(
              _view == _LinkView.contested
                  ? _LinkView.exceptions
                  : _LinkView.contested,
            ),
            tooltip: 'Rattachements que le joueur conteste',
          ),
          AdminStat(
            label: 'à réexaminer',
            value: '$reviewCount',
            tone: reviewCount > 0 ? AdminTheme.warning : null,
            selected: _view == _LinkView.review,
            onTap: () => _setView(
              _view == _LinkView.review
                  ? _LinkView.exceptions
                  : _LinkView.review,
            ),
            tooltip: 'Affiliations signalées après un retrait d’habilitation',
          ),
          AdminStat(
            label: 'doublons',
            value: '$duplicateCount',
            tone: duplicateCount > 0 ? AdminTheme.cyan : null,
            selected: _view == _LinkView.duplicates,
            onTap: () => _setView(
              _view == _LinkView.duplicates
                  ? _LinkView.exceptions
                  : _LinkView.duplicates,
            ),
            tooltip: 'Deux rattachements en cours sur le même joueur',
          ),
          AdminStat(label: 'en cours', value: '${allLinks.length}'),
        ],
      );

      // Un doublon est une propriété ENTRE documents : aucune requête
      // Firestore ne sait l'exprimer, il se voit en lisant la collection.
      // Tant que la fenêtre n'est pas complète, deux rattachements d'un même
      // joueur peuvent tomber dans deux pages, et le compteur sous-estime.
      // Le dire vaut mieux qu'un chiffre qu'on croit exhaustif.
      final notice = _controller.hasMore.value
          ? const AdminInfoBanner(
              title: 'Détection des doublons partielle',
              message:
                  'Tous les rattachements en cours ne sont pas chargés. Un '
                  'doublon se repère en comparant deux documents : chargez la '
                  'suite avant de conclure qu’il n’y en a pas.',
              icon: Icons.layers_outlined,
              tone: AdminBannerTone.warning,
            )
          : null;

      final Widget body;
      if (filtered.isEmpty) {
        body = allLinks.isEmpty
            ? AdminEmptyState(
                title: 'Aucun rattachement en cours',
                message: 'Aucun club n’a de déclaration ouverte sur un joueur.',
                icon: Icons.link_rounded,
                actionLabel: 'Recharger',
                actionIcon: Icons.refresh_rounded,
                onAction: _controller.refreshLinks,
              )
            : AdminEmptyState(
                title: _view == _LinkView.exceptions
                    ? 'Aucune exception à trancher'
                    : 'Aucun rattachement dans cette vue',
                message: _view == _LinkView.exceptions
                    ? 'Les rattachements en cours suivent leur cours : aucune '
                          'contestation, aucun réexamen, aucun doublon.'
                    : 'Aucun rattachement ne correspond à cette vue.',
                icon: Icons.task_alt_rounded,
                actionLabel: 'Réinitialiser',
                actionIcon: Icons.filter_alt_off_rounded,
                onAction: _clearFilters,
              );
      } else if (compact) {
        body = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final link in displayed) ...[
              _buildLinkCard(link, duplicates),
              const SizedBox(height: AdminTheme.space2),
            ],
          ],
        );
      } else {
        body = AdminTable(
          minWidth: _tableMinWidth,
          columns: const [
            AdminColumn(label: 'Joueur', flex: 3),
            AdminColumn(label: 'Club déclarant', flex: 3),
            AdminColumn(label: 'État', flex: 3),
            AdminColumn(
              label: 'Exception',
              flex: 2,
              tooltip:
                  'Pourquoi ce rattachement attend une décision. Un dossier '
                  'peut cumuler les trois : la parole du joueur passe devant.',
            ),
            AdminColumn(label: 'Depuis', width: 110),
            AdminColumn(label: '', width: 64, alignRight: true),
          ],
          rowCount: displayed.length,
          rowKey: (index) => ValueKey(displayed[index].id),
          selectedRow: _selectedLinkId == null
              ? null
              : displayed.indexWhere((link) => link.id == _selectedLinkId),
          onRowTap: (index) =>
              setState(() => _selectedLinkId = displayed[index].id),
          cellsBuilder: (index) {
            final link = displayed[index];
            final exception = _exceptionLabel(link, duplicates);

            return [
              AdminCellIdentity(
                title: _accountLabel(link.playerUid),
                subtitle: link.playerUid,
              ),
              AdminCellIdentity(
                title: _clubLabel(link),
                subtitle: link.declaredUnderAgreementRef == null
                    ? 'Accord non référencé'
                    : 'Accord ${link.declaredUnderAgreementRef}',
              ),
              Text(
                link.statusLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              exception == null
                  ? const Text('—')
                  : Text(
                      exception,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AdminType.label.copyWith(
                        color: _exceptionColor(exception),
                      ),
                    ),
              Text(
                _waitingLabel(link),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AdminType.label,
              ),
              _buildRowActions(link),
            ];
          },
        );
      }

      final selected = _selectedLinkId == null
          ? null
          : filtered.where((link) => link.id == _selectedLinkId).firstOrNull;

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
                itemLabel: 'rattachements',
                hasMore: _controller.hasMore.value,
                searchLimited:
                    _controller.hasMore.value && _searchQuery.isNotEmpty,
                onLoadMore: _controller.loadMoreLinks,
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
