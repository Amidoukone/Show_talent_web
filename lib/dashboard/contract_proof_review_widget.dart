import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../config/app_environment.dart';
import '../controller/contract_proof_controller.dart';
import '../models/contract_status_proof.dart';
import '../models/user.dart';
import '../services/admin_document_service.dart';
import '../theme/admin_theme.dart';
import '../theme/admin_type.dart';
import '../utils/admin_date_format.dart';
import '../widgets/admin_document_preview.dart';
import '../utils/admin_pagination.dart';
import '../utils/admin_storage_reference.dart';
import '../widgets/admin_detail_panel.dart';
import '../widgets/admin_feedback.dart';
import '../widgets/admin_page.dart';
import '../widgets/admin_table.dart';
import '../widgets/admin_ui.dart';
import '../widgets/contract_proof_verdict_dialog.dart';

/// La file des pièces de statut contractuel à examiner.
///
/// Un joueur peut écrire « libre » dans sa fiche sans que personne n'ait rien
/// vérifié, et c'est précisément la déclaration qu'un club lit avant d'engager
/// des frais de déplacement et d'essai. La fiche publique n'affiche donc un
/// statut contractuel que sur pièce approuvée — et cet écran est le seul
/// endroit où une pièce est approuvée.
class ContractProofReviewWidget extends StatefulWidget {
  const ContractProofReviewWidget({
    super.key,
    this.controller,
    this.documentService,
  });

  /// Injectables pour les tests, résolus depuis GetX en production.
  final ContractProofController? controller;
  final AdminDocumentService? documentService;

  @override
  State<ContractProofReviewWidget> createState() =>
      _ContractProofReviewWidgetState();
}

class _ContractProofReviewWidgetState extends State<ContractProofReviewWidget> {
  static const int _rowsPerPage = 25;

  /// Largeur en deçà de laquelle le tableau défile horizontalement. Sert
  /// aussi à AdminWorkspace pour décider si la fiche tient à côté.
  static const double _tableMinWidth = 980;

  /// Ancienneté à partir de laquelle une pièce est signalée comme en retard.
  ///
  /// Sept jours : le joueur a rassemblé un document et attend un verdict pour
  /// que sa fiche dise quelque chose à un recruteur. Au-delà d'une semaine,
  /// l'attente n'est plus un délai de traitement, c'est un oubli.
  static const Duration _staleAfter = Duration(days: 7);

  late final ContractProofController _controller;
  late final AdminDocumentService _documentService;
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  int _currentPage = 0;

  /// Compte dont une action est en vol, pour désarmer sa ligne.
  String? _actionUid;
  final Map<String, String> _openedProofs = {};

  /// Pièce ouverte dans la fiche latérale. L'identifiant plutôt que l'objet :
  /// la file se rafraîchit en continu, et une copie figée afficherait un état
  /// périmé après un verdict.
  String? _selectedUid;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? Get.find<ContractProofController>();
    _documentService =
        widget.documentService ??
        (AppEnvironmentConfig.visualQaMode
            ? AdminDocumentService.visualQa()
            : AdminDocumentService());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _isCompactLayout(BuildContext context) =>
      MediaQuery.sizeOf(context).width < AdminTheme.breakpointCompact;

  void _clearSearch() {
    setState(() {
      _searchQuery = '';
      _currentPage = 0;
      _searchController.clear();
    });
  }

  /// Depuis combien de temps la pièce attend, en deux ou trois caractères.
  ///
  /// Volontairement court : la valeur s'affiche dans une puce, et `AdminPill`
  /// pose son libellé dans une `Row` à taille minimale, sans troncature. Une
  /// phrase y déborderait de sa colonne au lieu de s'abréger — la date de
  /// dépôt complète vit dans la colonne voisine et dans la fiche.
  String _waitingLabel(ContractStatusProof proof) {
    final submittedAt = proof.submittedAt;
    if (submittedAt == null) return 'inconnue';

    final waited = DateTime.now().difference(submittedAt);
    if (waited.inDays >= 1) return '${waited.inDays} j';
    if (waited.inHours >= 1) return '${waited.inHours} h';
    return '< 1 h';
  }

  bool _isStale(ContractStatusProof proof) {
    final submittedAt = proof.submittedAt;
    if (submittedAt == null) return true;
    return DateTime.now().difference(submittedAt) >= _staleAfter;
  }

  /// Ce que le joueur déclare, tel qu'un opérateur le lit.
  String _declaredStatusLabel(AppUser user) {
    final status = user.football.contractStatus;
    if (status == null) return 'Aucun statut déclaré';

    final endDate = user.football.contractEndDate;
    if (!status.expectsEndDate || endDate == null) return status.labelFr;
    return '${status.labelFr}, jusqu’au ${formatAdminDate(endDate)}';
  }

  /// Pourquoi un verdict est impossible sur cette pièce, ou `null`.
  ///
  /// C'est la leçon tirée du consentement vidéo : désarmer l'action en disant
  /// pourquoi, plutôt que de laisser l'opérateur buter sur un refus serveur
  /// qu'aucun écran n'explique. Le callable refuse un joueur dont la pièce n'a
  /// pas de fichier lisible (`failed-precondition`), et une référence qui n'est
  /// pas une adresse `gs://` ne désigne rien que ce portail puisse ouvrir.
  String? _verdictBlockedReason(AppUser user) {
    final proof = user.contractStatusProof;
    if (!proof.hasFile) {
      return 'Cette pièce ne porte aucun fichier : il n’y a rien à examiner.';
    }
    if (!AdminStorageReference.isSupported(proof.fileUrl)) {
      return 'La référence du fichier n’est pas exploitable par le portail.';
    }
    if (_openedProofs[user.uid] != proof.fileUrl) {
      return 'Ouvrez cette pièce avant de rendre le verdict.';
    }
    return null;
  }

  Future<void> _openProof(AppUser user) async {
    final proof = user.contractStatusProof;
    if (!proof.hasFile) {
      showAdminFeedback(
        title: 'Aucun fichier',
        message: 'Cette pièce ne porte aucun fichier à ouvrir.',
        tone: AdminBannerTone.warning,
        position: SnackPosition.BOTTOM,
      );
      return;
    }

    setState(() => _actionUid = user.uid);

    final link = await _documentService.resolve(proof.fileUrl);

    if (!mounted) return;
    setState(() => _actionUid = null);

    if (!link.success) {
      showAdminFeedback(
        title: 'Ouverture impossible',
        message: link.message,
        tone: AdminBannerTone.danger,
        position: SnackPosition.BOTTOM,
      );
      return;
    }

    final consulted = await showAdminDocumentPreview(context, link);
    if (mounted && consulted) {
      setState(() => _openedProofs[user.uid] = proof.fileUrl!);
    }
  }

  Future<void> _reviewProof(AppUser user) async {
    final blocked = _verdictBlockedReason(user);
    if (blocked != null) {
      showAdminFeedback(
        title: 'Examen impossible',
        message: blocked,
        tone: AdminBannerTone.warning,
        position: SnackPosition.BOTTOM,
      );
      return;
    }

    final expectedFileUrl = _openedProofs[user.uid]!;
    final verdict = await showDialog<ContractProofVerdict>(
      context: context,
      builder: (context) => ContractProofVerdictDialog(user: user),
    );

    if (verdict == null || !mounted) return;

    setState(() => _actionUid = user.uid);

    final response = await _controller.reviewProof(
      uid: user.uid,
      expectedFileUrl: expectedFileUrl,
      status: verdict.approved
          ? ContractStatusProof.statusApproved
          : ContractStatusProof.statusRejected,
      contractStatus: verdict.contractStatus?.code,
      contractEndDate: verdict.contractEndDate,
      note: verdict.note,
    );

    if (!mounted) return;
    setState(() {
      _actionUid = null;
      if (response.success && _selectedUid == user.uid) {
        _selectedUid = null;
      }
    });

    if (response.success) {
      showAdminFeedback(
        title: verdict.approved ? 'Pièce approuvée' : 'Pièce écartée',
        message: verdict.approved
            ? 'Statut « ${verdict.contractStatus!.labelFr} » couvert pour '
                  '${user.nom}.'
            : 'La fiche de ${user.nom} n’affichera aucun statut contractuel.',
        tone: AdminBannerTone.success,
        position: SnackPosition.BOTTOM,
      );
      return;
    }

    showAdminFeedback(
      title: 'Examen impossible',
      message: response.message.trim().isNotEmpty
          ? response.message
          : 'Examen de la pièce impossible pour le moment.',
      tone: AdminBannerTone.danger,
      position: SnackPosition.BOTTOM,
    );
  }

  AdminRowActions _buildRowActions(AppUser user) {
    final blocked = _verdictBlockedReason(user);
    final proof = user.contractStatusProof;

    return AdminRowActions(
      busy: _actionUid == user.uid,
      primary: [
        AdminRowAction(
          icon: Icons.description_outlined,
          label: proof.hasFile
              ? 'Ouvrir la pièce'
              : 'Ouvrir la pièce (aucun fichier)',
          color: AdminTheme.cyan,
          onPressed: proof.hasFile ? () => _openProof(user) : null,
        ),
        AdminRowAction(
          icon: Icons.gavel_rounded,
          label: blocked ?? 'Examiner',
          color: AdminTheme.success,
          onPressed: blocked == null ? () => _reviewProof(user) : null,
        ),
      ],
    );
  }

  Widget _buildProofCard(AppUser user) {
    final proof = user.contractStatusProof;
    final reference = AdminStorageReference.parse(proof.fileUrl);

    return AdminDataCard(
      onTap: () => setState(() => _selectedUid = user.uid),
      title: Text(user.nom, style: AdminType.bodyStrong),
      subtitle: Text(_declaredStatusLabel(user), style: AdminType.caption),
      trailing: AdminPill(
        label: _waitingLabel(proof),
        color: _isStale(proof) ? AdminTheme.warning : AdminTheme.cyan,
      ),
      fields: [
        AdminDataCardField(
          label: 'Déposée le',
          value: Text(
            proof.submittedAt == null
                ? 'Date illisible'
                : formatAdminDateTime(proof.submittedAt!),
          ),
        ),
        AdminDataCardField(
          label: 'Fichier',
          value: Text(reference?.fileName ?? 'Aucun'),
        ),
      ],
      actions: _buildRowActions(user),
    );
  }

  Widget _buildDetailPanel(AppUser user, List<AppUser> queue) {
    final index = queue.indexWhere((item) => item.uid == user.uid);
    final proof = user.contractStatusProof;
    final reference = AdminStorageReference.parse(proof.fileUrl);
    final blocked = _verdictBlockedReason(user);

    return AdminDetailPanel(
      title: user.nom,
      subtitle: _declaredStatusLabel(user),
      position: index < 0 ? null : '${index + 1} / ${queue.length}',
      onPrevious: index > 0
          ? () => setState(() => _selectedUid = queue[index - 1].uid)
          : null,
      onNext: index >= 0 && index < queue.length - 1
          ? () => setState(() => _selectedUid = queue[index + 1].uid)
          : null,
      onClose: () => setState(() => _selectedUid = null),
      actions: [
        OutlinedButton(
          onPressed: _actionUid == user.uid || !proof.hasFile
              ? null
              : () => _openProof(user),
          child: const Text('Ouvrir la pièce'),
        ),
        ElevatedButton(
          onPressed: _actionUid == user.uid || blocked != null
              ? null
              : () => _reviewProof(user),
          child: const Text('Examiner'),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          AdminDetailSection(
            title: 'Pièce déposée',
            children: [
              AdminDetailField(
                label: 'Déposée le',
                value: proof.submittedAt == null
                    ? 'Date illisible'
                    : formatAdminDateTime(proof.submittedAt!),
              ),
              AdminDetailField(label: 'Attente', value: _waitingLabel(proof)),
              AdminDetailField(
                label: 'Fichier',
                value: reference?.fileName ?? 'Aucun',
              ),
              AdminDetailField(
                label: 'Format',
                value: reference == null
                    ? ''
                    : (reference.looksLikeImage
                          ? 'Image (${reference.extension})'
                          : reference.extension.toUpperCase()),
              ),
              if (blocked != null)
                AdminDetailField(
                  label: 'Examen',
                  value: blocked,
                  valueColor: AdminTheme.warning,
                ),
            ],
          ),
          AdminDetailSection(
            title: 'Ce que le joueur déclare',
            children: [
              AdminDetailField(
                label: 'Statut',
                value: user.football.contractStatus?.labelFr ?? 'Aucun',
              ),
              AdminDetailField(
                label: 'Fin de contrat',
                value: user.football.contractEndDate == null
                    ? ''
                    : formatAdminDate(user.football.contractEndDate!),
              ),
              AdminDetailField(
                label: 'Club actuel',
                value: user.football.currentClubName ?? '',
              ),
              AdminDetailField(label: 'Identifiant', value: user.uid),
            ],
          ),
          AdminDetailSection(
            title: 'Ce qu’un verdict change',
            children: [
              Text(
                'Approuver enregistre le statut que la pièce justifie. La '
                'fiche publique ne l’affiche que si le joueur déclare le même '
                'statut, date de fin comprise : une approbation ne sert pas '
                'de caution à une déclaration que personne n’a lue.\n\n'
                'Écarter ne touche ni le compte ni le dossier. La fiche cesse '
                'd’afficher un statut contractuel, et le joueur peut déposer '
                'une autre pièce.',
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

  @override
  Widget build(BuildContext context) {
    final compact = _isCompactLayout(context);

    final toolbar = AdminToolbar(
      filters: [
        AdminSearchField(
          controller: _searchController,
          hintText: 'Rechercher un joueur, un identifiant ou un statut',
          onChanged: (value) {
            setState(() {
              _searchQuery = value.trim().toLowerCase();
              _currentPage = 0;
            });
          },
        ),
      ],
      trailing: [
        IconButton(
          onPressed: _searchQuery.isEmpty ? null : _clearSearch,
          icon: const Icon(Icons.filter_alt_off_rounded, size: 17),
          tooltip: 'Effacer la recherche',
        ),
        IconButton(
          onPressed: _controller.refreshProofs,
          icon: const Icon(Icons.refresh_rounded, size: 17),
          tooltip: 'Recharger la file',
        ),
      ],
    );

    return Obx(() {
      if (_controller.isLoading.value) {
        return const AdminLoadingState(message: 'Chargement des pièces…');
      }

      final loadError = _controller.lastError.value;
      if (loadError.isNotEmpty) {
        return AdminEmptyState(
          title: 'Chargement incomplet',
          message: loadError,
          icon: Icons.error_outline_rounded,
          actionLabel: 'Réessayer',
          actionIcon: Icons.refresh_rounded,
          onAction: _controller.refreshProofs,
        );
      }

      final allProofs = _controller.pendingProofs;
      final filtered = allProofs.where((user) {
        if (_searchQuery.isEmpty) return true;
        return [
          user.nom,
          user.uid,
          _declaredStatusLabel(user),
          user.football.currentClubName,
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

      final staleCount = allProofs
          .where((user) => _isStale(user.contractStatusProof))
          .length;
      final unreadableCount = allProofs
          .where(
            (user) => !AdminStorageReference.isSupported(
              user.contractStatusProof.fileUrl,
            ),
          )
          .length;

      final stats = AdminStatStrip(
        stats: [
          AdminStat(
            label: 'en attente',
            value: '${allProofs.length + _controller.unreadableProfiles.value}',
          ),
          if (_controller.unreadableProfiles.value > 0)
            AdminStat(
              label: 'dossiers illisibles',
              value: '${_controller.unreadableProfiles.value}',
              tone: AdminTheme.warning,
            ),
          AdminStat(
            label: 'depuis plus de 7 jours',
            value: '$staleCount',
            tone: staleCount > 0 ? AdminTheme.warning : null,
          ),
          AdminStat(
            label: 'sans fichier exploitable',
            value: '$unreadableCount',
            tone: unreadableCount > 0 ? AdminTheme.warning : null,
          ),
        ],
      );

      final Widget body;
      if (filtered.isEmpty && _controller.hasMore.value) {
        body = AdminEmptyState(
          title: 'Aucun résultat parmi les pièces chargées',
          message: 'La file contient encore des dossiers à consulter.',
          icon: Icons.search,
          actionLabel: 'Charger les pièces suivantes',
          onAction: _controller.loadMoreProofs,
        );
      } else if (allProofs.isEmpty &&
          _controller.unreadableProfiles.value > 0) {
        body = AdminEmptyState(
          title: 'Dossiers en attente illisibles',
          message: 'Les données de ces dossiers ne permettent pas leur examen.',
          icon: Icons.error_outline,
          actionLabel: 'Recharger',
          onAction: _controller.refreshProofs,
        );
      } else if (filtered.isEmpty) {
        body = allProofs.isEmpty
            ? AdminEmptyState(
                title: 'Aucune pièce à examiner',
                message:
                    'Aucun joueur n’attend un verdict sur son statut '
                    'contractuel.',
                icon: Icons.task_alt_rounded,
                actionLabel: 'Recharger',
                actionIcon: Icons.refresh_rounded,
                onAction: _controller.refreshProofs,
              )
            : AdminEmptyState(
                title: 'Aucune pièce dans cette vue',
                message: 'Aucune pièce ne correspond à cette recherche.',
                icon: Icons.filter_alt_off_outlined,
                actionLabel: 'Effacer la recherche',
                actionIcon: Icons.filter_alt_off_rounded,
                onAction: _clearSearch,
              );
      } else if (compact) {
        body = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final user in displayed) ...[
              _buildProofCard(user),
              const SizedBox(height: AdminTheme.space2),
            ],
          ],
        );
      } else {
        body = AdminTable(
          minWidth: _tableMinWidth,
          columns: const [
            AdminColumn(label: 'Joueur', flex: 4),
            AdminColumn(
              label: 'Statut déclaré',
              flex: 3,
              tooltip:
                  'Ce que le joueur a saisi. La fiche publique ne l’affiche '
                  'que si une pièce approuvée couvre exactement ce '
                  'statut-là.',
            ),
            AdminColumn(label: 'Déposée le', width: 170),
            AdminColumn(label: 'Attente', width: 120),
            AdminColumn(label: '', width: 96, alignRight: true),
          ],
          rowCount: displayed.length,
          rowKey: (index) => ValueKey(displayed[index].uid),
          selectedRow: _selectedUid == null
              ? null
              : displayed.indexWhere((user) => user.uid == _selectedUid),
          onRowTap: (index) =>
              setState(() => _selectedUid = displayed[index].uid),
          cellsBuilder: (index) {
            final user = displayed[index];
            final proof = user.contractStatusProof;
            final reference = AdminStorageReference.parse(proof.fileUrl);

            return [
              AdminCellIdentity(
                title: user.nom,
                subtitle: reference?.fileName ?? 'Aucun fichier',
                icon: Icons.description_outlined,
                iconColor: AdminTheme.cyan,
              ),
              Text(
                _declaredStatusLabel(user),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                proof.submittedAt == null
                    ? 'Date illisible'
                    : formatAdminDateTime(proof.submittedAt!),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              // Texte simple et non une puce : `AdminPill` pose son libellé
              // dans une `Row` à taille minimale, sans troncature, donc une
              // valeur calculée de longueur variable y déborde de sa colonne
              // au lieu de s'abréger. Mesuré, pas supposé : « inconnue »
              // dépassait de vingt pixels.
              Text(
                _waitingLabel(proof),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AdminType.label.copyWith(
                  color: _isStale(proof)
                      ? AdminTheme.warning
                      : AdminTheme.textSecondary,
                ),
              ),
              _buildRowActions(user),
            ];
          },
        );
      }

      final selected = _selectedUid == null
          ? null
          : filtered.where((user) => user.uid == _selectedUid).firstOrNull;

      return AdminWorkspace(
        compact: compact,
        bodyMinWidth: _tableMinWidth,
        toolbar: toolbar,
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
                itemLabel: 'pièces',
                hasMore: _controller.hasMore.value,
                searchLimited:
                    _controller.hasMore.value && _searchQuery.isNotEmpty,
                onLoadMore: _controller.loadMoreProofs,
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
