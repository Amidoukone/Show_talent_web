import 'package:flutter/material.dart';

import '../models/contract_status_proof.dart';
import '../models/football_vocabulary.dart';
import '../models/user.dart';
import '../theme/admin_theme.dart';
import '../theme/admin_type.dart';
import '../utils/admin_date_format.dart';

/// Ce que l'opérateur a décidé sur une pièce de statut contractuel.
class ContractProofVerdict {
  const ContractProofVerdict.approve({
    required this.contractStatus,
    this.contractEndDate,
    this.note,
  }) : approved = true;

  const ContractProofVerdict.reject({required this.note})
    : approved = false,
      contractStatus = null,
      contractEndDate = null;

  /// Si la pièce est retenue.
  final bool approved;

  /// Statut contractuel que la pièce justifie, obligatoire pour approuver.
  final ContractStatus? contractStatus;

  /// Fin de contrat couverte, quand le statut en attend une.
  final DateTime? contractEndDate;

  /// Motif, lisible par le joueur. Obligatoire pour écarter.
  final String? note;
}

/// Approuve ou écarte la pièce de statut contractuel d'un joueur.
///
/// Les deux décisions vivent dans le même dialogue parce qu'elles se posent au
/// même moment, devant la même pièce ouverte dans l'onglet voisin.
///
/// **Approuver, c'est dire quel statut la pièce justifie**, et pas seulement
/// « oui ». C'est cette valeur-là que la projection publique recompare au
/// statut saisi par le joueur avant de publier quoi que ce soit : sans elle,
/// l'approbation servirait de caution à une déclaration que personne n'a lue.
/// Le dialogue la présélectionne donc sur ce que le joueur déclare — le cas
/// courant étant que l'opérateur confirme la déclaration — et signale tout de
/// suite le cas où le verdict ne publiera rien.
class ContractProofVerdictDialog extends StatefulWidget {
  const ContractProofVerdictDialog({required this.user, super.key});

  final AppUser user;

  @override
  State<ContractProofVerdictDialog> createState() =>
      _ContractProofVerdictDialogState();
}

class _ContractProofVerdictDialogState
    extends State<ContractProofVerdictDialog> {
  late final TextEditingController _noteController;

  bool _rejecting = false;
  ContractStatus? _contractStatus;
  DateTime? _contractEndDate;

  AppUser get _user => widget.user;
  ContractStatusProof get _proof => _user.contractStatusProof;

  /// Ce que le joueur déclare aujourd'hui sur sa fiche.
  ContractStatus? get _declaredStatus => _user.football.contractStatus;
  DateTime? get _declaredEndDate => _user.football.contractEndDate;

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController();
    // Présélection sur la déclaration du joueur : l'examen consiste le plus
    // souvent à confirmer ce qu'il a écrit, pièce en main. Un statut déjà
    // couvert par un examen précédent l'emporte, lui qui est le dernier
    // verdict rendu.
    _contractStatus = _proof.approvedContractStatus ?? _declaredStatus;
    _contractEndDate = _proof.approvedContractEndDate ?? _declaredEndDate;
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  bool get _expectsEndDate => _contractStatus?.expectsEndDate ?? false;

  /// Si le verdict en préparation ne publiera rien sur la fiche.
  ///
  /// Le cas est contre-intuitif et vaut un avertissement : tout est en ordre
  /// côté examen, et la fiche reste muette parce que le joueur déclare autre
  /// chose. Le dire avant le verdict évite qu'un opérateur conclue à une panne
  /// une fois la pièce approuvée.
  String? get _publicationWarning {
    final chosen = _contractStatus;
    if (_rejecting || chosen == null) return null;

    if (_declaredStatus == null) {
      return 'Ce joueur n’a aucun statut contractuel sur sa fiche. '
          'L’approbation sera enregistrée, et rien ne sera publié tant qu’il '
          'n’aura pas saisi « ${chosen.labelFr} » de son côté.';
    }

    if (_declaredStatus != chosen) {
      return 'Ce joueur déclare « ${_declaredStatus!.labelFr} » et vous '
          'approuvez « ${chosen.labelFr} ». Rien ne sera publié tant que les '
          'deux ne concordent pas.';
    }

    if (!chosen.expectsEndDate) return null;

    final declaredEnd = _declaredEndDate;
    final chosenEnd = _contractEndDate;
    if (declaredEnd == null || chosenEnd == null) return null;
    if (!declaredEnd.isAtSameMomentAs(chosenEnd)) {
      return 'La fin de contrat déclarée est le '
          '${formatAdminDate(declaredEnd)} et vous approuvez le '
          '${formatAdminDate(chosenEnd)}. Rien ne sera publié tant que les '
          'deux dates ne concordent pas.';
    }

    return null;
  }

  Future<void> _pickEndDate() async {
    final now = DateTime.now();
    final declared = _declaredEndDate;
    final current = _contractEndDate;

    // La borne basse descend jusqu'à la date déclarée quand elle est passée :
    // confirmer exactement ce que le joueur a écrit doit rester possible, même
    // si ce qu'il a écrit est une fin de contrat déjà échue. Sans cette borne,
    // le sélecteur refuserait la seule date qui publie quelque chose.
    final earliest = <DateTime>[
      DateTime(now.year, now.month, now.day),
      ?declared,
      ?current,
    ].reduce((a, b) => a.isBefore(b) ? a : b);
    final latest = DateTime(now.year + 10, now.month, now.day);

    final initial =
        current ?? declared ?? DateTime(now.year, now.month, now.day);
    final clamped = initial.isBefore(earliest)
        ? earliest
        : (initial.isAfter(latest) ? latest : initial);

    final picked = await showDatePicker(
      context: context,
      initialDate: clamped,
      firstDate: earliest,
      lastDate: latest,
      helpText: 'Fin de contrat couverte par la pièce',
      cancelText: 'Annuler',
      confirmText: 'Valider',
    );

    if (picked == null) return;
    setState(() => _contractEndDate = picked);
  }

  bool get _canSubmit {
    if (_rejecting) {
      // Un motif est exigé pour écarter : le joueur reçoit un verdict
      // défavorable sur une pièce qu'il a dû rassembler, et « refusée » sans
      // un mot le laisse sans rien à corriger. Il n'est pas exigé pour
      // approuver, l'approbation se suffisant à elle-même.
      return _noteController.text.trim().isNotEmpty;
    }

    if (_contractStatus == null) return false;
    if (_expectsEndDate && _contractEndDate == null) return false;
    return true;
  }

  void _submit() {
    final note = _noteController.text.trim();

    if (_rejecting) {
      Navigator.of(context).pop(ContractProofVerdict.reject(note: note));
      return;
    }

    Navigator.of(context).pop(
      ContractProofVerdict.approve(
        contractStatus: _contractStatus!,
        // Envoyée seulement quand le statut en attend une : une date sur un
        // statut « libre » n'a pas de sens, et le serveur ne la lirait pas.
        contractEndDate: _expectsEndDate ? _contractEndDate : null,
        note: note.isEmpty ? null : note,
      ),
    );
  }

  Widget _caption(String text, {Color? color}) {
    return Text(
      text,
      style: AdminType.caption.copyWith(
        color: color ?? AdminTheme.textSecondary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final submittedAt = _proof.submittedAt;
    final warning = _publicationWarning;
    final endDate = _contractEndDate;

    return AlertDialog(
      title: Text('Examen de la pièce - ${_user.nom}'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _caption(
                submittedAt == null
                    ? 'Pièce déposée, sans date de dépôt lisible.'
                    : 'Pièce déposée le ${formatAdminDateTime(submittedAt)}.',
              ),
              const SizedBox(height: AdminTheme.space1),
              _caption(
                _declaredStatus == null
                    ? 'Statut déclaré sur la fiche : aucun.'
                    : 'Statut déclaré sur la fiche : '
                          '${_declaredStatus!.labelFr}'
                          '${_declaredEndDate == null ? '' : ', jusqu’au ${formatAdminDate(_declaredEndDate!)}'}.',
              ),
              const SizedBox(height: AdminTheme.space4),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment<bool>(value: false, label: Text('Approuver')),
                  ButtonSegment<bool>(value: true, label: Text('Écarter')),
                ],
                selected: {_rejecting},
                onSelectionChanged: (selection) {
                  setState(() => _rejecting = selection.first);
                },
              ),
              const SizedBox(height: AdminTheme.space4),
              if (_rejecting) ...[
                _caption(
                  'Écarter ne touche ni le compte ni le dossier du joueur : '
                  'sa fiche cesse seulement d’afficher un statut contractuel. '
                  'Il peut déposer une autre pièce.',
                ),
                const SizedBox(height: AdminTheme.space3),
                TextField(
                  controller: _noteController,
                  maxLines: 3,
                  maxLength: ContractStatusProof.maxReviewNoteLength,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Motif transmis au joueur',
                    hintText:
                        'Document illisible, nom différent de celui du compte…',
                    border: const OutlineInputBorder(),
                    errorText: _noteController.text.trim().isEmpty
                        ? 'Un motif est requis pour écarter une pièce.'
                        : null,
                  ),
                ),
              ] else ...[
                Text(
                  'Quel statut cette pièce justifie-t-elle ?',
                  style: AdminType.labelStrong,
                ),
                const SizedBox(height: AdminTheme.space2),
                Wrap(
                  spacing: AdminTheme.space2,
                  runSpacing: AdminTheme.space2,
                  children: [
                    for (final candidate in ContractStatus.values)
                      ChoiceChip(
                        label: Text(candidate.labelFr),
                        selected: _contractStatus == candidate,
                        onSelected: (_) =>
                            setState(() => _contractStatus = candidate),
                      ),
                  ],
                ),
                if (_expectsEndDate) ...[
                  const SizedBox(height: AdminTheme.space4),
                  OutlinedButton.icon(
                    onPressed: _pickEndDate,
                    icon: const Icon(Icons.event_outlined),
                    label: Text(
                      endDate == null
                          ? 'Choisir la fin de contrat'
                          : 'Jusqu’au ${formatAdminDate(endDate)}',
                    ),
                  ),
                  const SizedBox(height: AdminTheme.space2),
                  _caption(
                    'Ce statut attend une date de fin : une fin de contrat '
                    'repoussée de deux ans change ce qu’un club lit, autant '
                    'que le statut lui-même.',
                  ),
                ],
                const SizedBox(height: AdminTheme.space4),
                TextField(
                  controller: _noteController,
                  maxLines: 2,
                  maxLength: ContractStatusProof.maxReviewNoteLength,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Motif (optionnel)',
                    hintText: 'Contrat de travail signé, daté et lisible.',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
              if (warning != null) ...[
                const SizedBox(height: AdminTheme.space3),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      size: 16,
                      color: AdminTheme.warning,
                    ),
                    const SizedBox(width: AdminTheme.space2),
                    Expanded(
                      child: _caption(warning, color: AdminTheme.warning),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _canSubmit ? _submit : null,
          child: Text(_rejecting ? 'Écarter' : 'Approuver'),
        ),
      ],
    );
  }
}
