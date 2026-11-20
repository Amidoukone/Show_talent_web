import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../config/app_environment.dart';
import '../models/club_enrollment.dart';
import '../models/user.dart';
import '../services/admin_document_service.dart';
import '../theme/admin_theme.dart';
import '../theme/admin_type.dart';
import '../utils/admin_date_format.dart';
import 'admin_document_preview.dart';
import '../utils/admin_file_picker.dart';
import 'admin_feedback.dart';
import 'admin_ui.dart';

/// Ce que l'administrateur a décidé sur l'habilitation d'un club.
class ClubEnrollmentDecision {
  const ClubEnrollmentDecision.grant({
    required this.agreementRef,
    required this.validUntil,
  }) : revoke = false,
       reason = null;

  const ClubEnrollmentDecision.revoke({this.reason})
    : revoke = true,
      agreementRef = null,
      validUntil = null;

  /// Si la décision est un retrait.
  final bool revoke;

  /// Référence de l'accord signé, obligatoire pour accorder.
  final String? agreementRef;

  /// Terme de l'habilitation, obligatoire pour accorder.
  final DateTime? validUntil;

  /// Motif du retrait, consigné sur le club et sur ce qu'il a déclaré.
  final String? reason;
}

/// Accorde ou retire à un club le droit de déclarer ses joueurs.
///
/// Les deux décisions vivent dans le même dialogue parce qu'elles se posent au
/// même moment, devant la même ligne, mais elles ne passent pas par le même
/// appel : accorder écrit un droit, retirer traite en plus tout ce que le club
/// a déclaré pendant qu'il était habilité.
///
/// Le dialogue ne parle d'aucun montant, et c'est voulu : l'enrôlement ne
/// s'achète pas. L'abonnement professionnel a son propre dialogue.
///
/// **Le document de l'accord se dépose ici**, à côté de sa référence.
/// `storage.rules` réserve `clubAgreements/{clubUid}/` à l'administration dans
/// les deux sens : le club n'y accède pas, parce qu'un accord est un acte
/// signé entre deux parties et non une pièce que son propriétaire dépose. Il
/// en a son exemplaire, et l'application mobile n'en parle à personne.
class ClubEnrollmentDialog extends StatefulWidget {
  const ClubEnrollmentDialog({
    required this.user,
    this.documentService,
    super.key,
  });

  final AppUser user;

  /// Injectable pour les tests.
  final AdminDocumentService? documentService;

  @override
  State<ClubEnrollmentDialog> createState() => _ClubEnrollmentDialogState();
}

class _ClubEnrollmentDialogState extends State<ClubEnrollmentDialog> {
  late final TextEditingController _agreementController;
  late final TextEditingController _reasonController;
  late final AdminDocumentService _documentService;

  DateTime? _validUntil;
  bool _revoking = false;

  /// Accords déjà déposés, `null` tant que la lecture n'a pas répondu.
  List<AdminStoredDocument>? _agreements;
  String? _agreementsError;
  bool _busyOnDocument = false;

  AppUser get _user => widget.user;
  ClubEnrollment get _current => _user.clubEnrollment;

  @override
  void initState() {
    super.initState();
    _agreementController = TextEditingController(
      text: _current.agreementRef ?? '',
    );
    _reasonController = TextEditingController();
    _validUntil = _current.validUntil;
    _revoking = _user.clubEnrollmentRevocationPending;
    _documentService =
        widget.documentService ??
        (AppEnvironmentConfig.visualQaMode
            ? AdminDocumentService.visualQa()
            : AdminDocumentService());
    _loadAgreements();
  }

  @override
  void dispose() {
    _agreementController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  /// Lit le dossier des accords du club.
  ///
  /// Un dossier vide n'est pas une erreur : la quasi-totalité des clubs n'ont
  /// jamais eu d'accord déposé, et traiter ce cas comme une panne ferait
  /// afficher un message d'erreur sur presque chaque ouverture.
  Future<void> _loadAgreements() async {
    try {
      final documents = await _documentService.listClubAgreements(_user.uid);
      if (!mounted) return;
      setState(() {
        _agreements = documents;
        _agreementsError = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _agreements = const <AdminStoredDocument>[];
        _agreementsError =
            'Impossible de lire les accords déjà déposés. Un dépôt reste '
            'possible.';
      });
    }
  }

  Future<void> _openAgreement(AdminStoredDocument document) async {
    setState(() => _busyOnDocument = true);
    final link = await _documentService.resolvePath(document.objectPath);
    if (!mounted) return;
    setState(() => _busyOnDocument = false);

    if (!link.success) {
      showAdminFeedback(
        title: 'Ouverture impossible',
        message: link.message,
        tone: AdminBannerTone.danger,
        position: SnackPosition.BOTTOM,
      );
      return;
    }

    await showAdminDocumentPreview(context, link);
  }

  /// Choisit un fichier et le dépose.
  ///
  /// La référence de l'accord est exigée **avant** le dépôt, et ce n'est pas
  /// une formalité d'ordre : elle entre dans le nom de l'objet stocké, qui est
  /// ce qui permet de reconnaître le bon document des mois plus tard.
  ///
  /// Le dépôt est immédiat et non différé à la validation du dialogue : il ne
  /// passe pas par le même chemin que l'habilitation — un écrit de stockage
  /// contre un callable — et les deux ne peuvent pas être rendus atomiques.
  /// Déposer d'abord est le bon ordre : un fichier sans habilitation est un
  /// document inerte dans un dossier que seule l'administration lit, alors
  /// qu'une habilitation sans son document laisse une référence qui ne pointe
  /// sur rien.
  Future<void> _uploadAgreement() async {
    final reference = _agreementController.text.trim();
    if (reference.isEmpty) {
      showAdminFeedback(
        title: 'Référence requise',
        message:
            'Saisissez d’abord la référence de l’accord : elle nomme le '
            'document déposé.',
        tone: AdminBannerTone.warning,
        position: SnackPosition.BOTTOM,
      );
      return;
    }

    if (!adminFilePickerSupported) {
      showAdminFeedback(
        title: 'Dépôt indisponible',
        message:
            'Le dépôt de document demande un navigateur. Ouvrez le portail '
            'sur le web pour téléverser un accord.',
        tone: AdminBannerTone.warning,
        position: SnackPosition.BOTTOM,
      );
      return;
    }

    final picked = await pickAdminFile(
      accept: '.pdf,.jpg,.jpeg,.png,application/pdf,image/jpeg,image/png',
    );
    // Annulation : rien à dire, l'opérateur vient de fermer son sélecteur.
    if (picked == null || !mounted) return;

    setState(() => _busyOnDocument = true);

    final result = await _documentService.uploadClubAgreement(
      clubUid: _user.uid,
      agreementRef: reference,
      file: picked,
    );

    if (!mounted) return;
    setState(() => _busyOnDocument = false);

    showAdminFeedback(
      title: result.success ? 'Accord déposé' : 'Dépôt impossible',
      message: result.message,
      tone: result.success ? AdminBannerTone.success : AdminBannerTone.danger,
      position: SnackPosition.BOTTOM,
    );

    if (result.success) {
      await _loadAgreements();
    }
  }

  Future<void> _pickValidUntil() async {
    final now = DateTime.now();
    final firstDate = DateTime(now.year, now.month, now.day + 1);
    // Deux jours de marge sur la limite du callable, comme pour les droits :
    // la date choisie est ramenée à 23h59, et un terme au dernier jour exact
    // serait refusé pour quelques heures de trop.
    final lastDate = now.add(
      ClubEnrollment.maxValidity - const Duration(days: 2),
    );
    final current = _validUntil;
    final initialDate = (current != null && current.isAfter(firstDate))
        ? (current.isBefore(lastDate) ? current : lastDate)
        : firstDate;

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: 'Terme de l’habilitation',
      cancelText: 'Annuler',
      confirmText: 'Valider',
    );

    if (picked == null) return;

    setState(() {
      // Fin de journée : une habilitation « jusqu’au 12 » vaut tout le 12.
      _validUntil = DateTime(picked.year, picked.month, picked.day, 23, 59);
    });
  }

  bool get _canSubmit {
    if (_busyOnDocument) return false;
    if (_user.clubEnrollmentRevocationPending) return _revoking;
    if (_revoking) return _current.granted;
    return _agreementController.text.trim().isNotEmpty &&
        _validUntil != null &&
        ClubEnrollment.isGrantDateValid(_validUntil!);
  }

  void _submit() {
    if (!_canSubmit) {
      setState(() {});
      return;
    }
    if (_revoking) {
      final reason = _reasonController.text.trim();
      Navigator.of(context).pop(
        ClubEnrollmentDecision.revoke(reason: reason.isEmpty ? null : reason),
      );
      return;
    }

    Navigator.of(context).pop(
      ClubEnrollmentDecision.grant(
        agreementRef: _agreementController.text.trim(),
        validUntil: _validUntil!,
      ),
    );
  }

  String _formatSize(int? bytes) {
    if (bytes == null) return '';
    if (bytes < 1024) return '$bytes o';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} Ko';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} Mo';
  }

  Widget _caption(String text, {Color? color}) {
    return Text(
      text,
      style: AdminType.caption.copyWith(
        color: color ?? AdminTheme.textSecondary,
      ),
    );
  }

  /// Le bloc du document signé : ce qui est déjà déposé, et un dépôt.
  Widget _buildAgreementDocuments() {
    final documents = _agreements;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Document de l’accord', style: AdminType.labelStrong),
        const SizedBox(height: AdminTheme.space2),
        if (documents == null)
          _caption('Lecture du dossier…')
        else if (documents.isEmpty)
          _caption(
            'Aucun document déposé pour ce club. La référence seule suffit à '
            'habiliter ; déposer l’accord signé permet de le relire plus tard.',
          )
        else
          for (final document in documents)
            Padding(
              padding: const EdgeInsets.only(bottom: AdminTheme.space1),
              child: Row(
                children: [
                  const Icon(
                    Icons.description_outlined,
                    size: 14,
                    color: AdminTheme.cyan,
                  ),
                  const SizedBox(width: AdminTheme.space2),
                  Expanded(
                    child: Text(
                      document.updatedAt == null
                          ? document.name
                          : '${document.name} · '
                                '${formatAdminDate(document.updatedAt!)}'
                                '${document.sizeBytes == null ? '' : ' · ${_formatSize(document.sizeBytes)}'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AdminType.caption,
                    ),
                  ),
                  TextButton(
                    onPressed: _busyOnDocument
                        ? null
                        : () => _openAgreement(document),
                    child: const Text('Ouvrir'),
                  ),
                ],
              ),
            ),
        if (_agreementsError != null) ...[
          const SizedBox(height: AdminTheme.space1),
          _caption(_agreementsError!, color: AdminTheme.warning),
        ],
        const SizedBox(height: AdminTheme.space2),
        OutlinedButton.icon(
          onPressed: _busyOnDocument ? null : _uploadAgreement,
          icon: const Icon(Icons.upload_file_outlined),
          label: Text(
            _busyOnDocument ? 'Dépôt en cours…' : 'Déposer l’accord signé',
          ),
        ),
        const SizedBox(height: AdminTheme.space2),
        _caption(
          'PDF ou photo, 8 Mo au plus. Le dossier est en lecture et en '
          'écriture pour l’administration seule : le club n’y accède pas.',
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final until = _validUntil;
    final agreement = _current.agreementRef;

    return AlertDialog(
      title: Text('Habilitation - ${_user.nom}'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Club : ${_user.nom} (${_user.email})'),
              const SizedBox(height: 6),
              Text(
                agreement == null
                    ? 'État actuel : ${_current.statusLabel}'
                    : 'État actuel : ${_current.statusLabel}, accord $agreement',
                style: const TextStyle(color: AdminTheme.textSecondary),
              ),
              if (_current.validUntil != null) ...[
                const SizedBox(height: 4),
                _caption(
                  _current.expired
                      ? 'Terme dépassé le ${formatAdminDate(_current.validUntil!)}'
                      : 'Terme : ${formatAdminDate(_current.validUntil!)}',
                  color: _current.expired || _current.expiresSoon()
                      ? AdminTheme.warning
                      : AdminTheme.textSecondary,
                ),
              ],
              const SizedBox(height: 16),
              Text(
                'L’habilitation autorise ce club à déclarer ses joueurs. Elle '
                'ne se paie pas et ne remplace pas l’abonnement '
                'professionnel, qui se gère à part.',
                style: AdminType.caption.copyWith(
                  color: AdminTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              SegmentedButton<bool>(
                segments: [
                  ButtonSegment<bool>(
                    value: false,
                    enabled: !_user.clubEnrollmentRevocationPending,
                    label: const Text('Accorder'),
                  ),
                  const ButtonSegment<bool>(
                    value: true,
                    label: Text('Retirer'),
                  ),
                ],
                selected: {_revoking},
                onSelectionChanged: (selection) {
                  setState(() => _revoking = selection.first);
                },
              ),
              const SizedBox(height: 16),
              if (_revoking) ...[
                Text(
                  'Le retrait annule les déclarations que les joueurs n’ont '
                  'pas encore confirmées, et signale pour réexamen les '
                  'affiliations déjà confirmées, sans les défaire : le joueur '
                  'les a acceptées, et il est bien dans ce club.',
                  style: AdminType.caption.copyWith(
                    color: AdminTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                if (!_user.clubEnrollmentRevocationPending)
                  TextField(
                    controller: _reasonController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Motif du retrait',
                      hintText: 'Accord non renouvelé, litige en cours…',
                      border: OutlineInputBorder(),
                    ),
                  ),
                if (_user.clubEnrollmentRevocationPending)
                  const Text(
                    'Le droit est retiré. Le traitement des rattachements reprendra automatiquement. Vous pouvez aussi le relancer maintenant.',
                  ),
                if (!_current.granted &&
                    !_user.clubEnrollmentRevocationPending) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Ce club n’a aucune habilitation à retirer.',
                    style: AdminType.caption.copyWith(color: AdminTheme.danger),
                  ),
                ],
              ] else ...[
                TextField(
                  controller: _agreementController,
                  enabled: !_busyOnDocument,
                  decoration: const InputDecoration(
                    labelText: 'Référence de l’accord signé',
                    hintText: 'ACCORD-2026-011',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 8),
                _caption(
                  'Tous les clubs ne signent pas le même accord : '
                  'l’habilitation pointe vers celui-ci, et le document '
                  'lui-même se dépose juste en dessous.',
                ),
                const SizedBox(height: 16),
                _buildAgreementDocuments(),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _pickValidUntil,
                  icon: const Icon(Icons.event_outlined),
                  label: Text(
                    until == null
                        ? 'Choisir le terme'
                        : 'Jusqu’au ${formatAdminDate(until)}',
                  ),
                ),
                const SizedBox(height: 8),
                if (until != null && !ClubEnrollment.isGrantDateValid(until))
                  _caption(
                    'Choisissez une échéance future dans la limite de cinq ans.',
                    color: AdminTheme.danger,
                  ),
                _caption(
                  'Le terme est obligatoire, contrairement à l’abonnement : '
                  'un droit que personne ne revisite finit par survivre à '
                  'l’accord qu’il représente.',
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
          child: Text(
            _user.clubEnrollmentRevocationPending
                ? 'Reprendre le retrait'
                : (_revoking ? 'Retirer' : 'Accorder'),
          ),
        ),
      ],
    );
  }
}
