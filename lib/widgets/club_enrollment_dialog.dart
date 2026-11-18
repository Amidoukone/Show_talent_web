import 'package:flutter/material.dart';

import '../models/club_enrollment.dart';
import '../models/user.dart';
import '../theme/admin_theme.dart';
import '../theme/admin_type.dart';

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
class ClubEnrollmentDialog extends StatefulWidget {
  const ClubEnrollmentDialog({required this.user, super.key});

  final AppUser user;

  @override
  State<ClubEnrollmentDialog> createState() => _ClubEnrollmentDialogState();
}

class _ClubEnrollmentDialogState extends State<ClubEnrollmentDialog> {
  late final TextEditingController _agreementController;
  late final TextEditingController _reasonController;
  DateTime? _validUntil;
  bool _revoking = false;

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
  }

  @override
  void dispose() {
    _agreementController.dispose();
    _reasonController.dispose();
    super.dispose();
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
    if (_revoking) return _current.granted;
    return _agreementController.text.trim().isNotEmpty && _validUntil != null;
  }

  void _submit() {
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

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
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
                segments: const [
                  ButtonSegment<bool>(value: false, label: Text('Accorder')),
                  ButtonSegment<bool>(value: true, label: Text('Retirer')),
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
                TextField(
                  controller: _reasonController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Motif du retrait',
                    hintText: 'Accord non renouvelé, litige en cours…',
                    border: OutlineInputBorder(),
                  ),
                ),
                if (!_current.granted) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Ce club n’a aucune habilitation à retirer.',
                    style: AdminType.caption.copyWith(color: AdminTheme.danger),
                  ),
                ],
              ] else ...[
                TextField(
                  controller: _agreementController,
                  decoration: const InputDecoration(
                    labelText: 'Référence de l’accord signé',
                    hintText: 'ACCORD-2026-011',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tous les clubs ne signent pas le même accord : '
                  'l’habilitation pointe vers celui-ci, et le document '
                  'lui-même se téléverse à part.',
                  style: AdminType.caption.copyWith(
                    color: AdminTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _pickValidUntil,
                  icon: const Icon(Icons.event_outlined),
                  label: Text(
                    until == null
                        ? 'Choisir le terme'
                        : 'Jusqu’au ${_formatDate(until)}',
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Le terme est obligatoire, contrairement à l’abonnement : '
                  'un droit que personne ne revisite finit par survivre à '
                  'l’accord qu’il représente.',
                  style: AdminType.caption.copyWith(
                    color: AdminTheme.textSecondary,
                  ),
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
          child: Text(_revoking ? 'Retirer' : 'Accorder'),
        ),
      ],
    );
  }
}
