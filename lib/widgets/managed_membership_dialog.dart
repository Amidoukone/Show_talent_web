import 'package:flutter/material.dart';

import '../models/membership.dart';
import '../models/user.dart';
import '../theme/admin_theme.dart';
import '../theme/admin_type.dart';

/// Ce que l'administrateur a décidé dans le dialogue des droits.
class MembershipDecision {
  const MembershipDecision({
    required this.tier,
    this.validUntil,
    this.reference,
  });

  final MembershipTier tier;
  final DateTime? validUntil;
  final String? reference;

  String get summaryLabel {
    if (tier == MembershipTier.none) {
      return 'aucun droit';
    }

    final until = validUntil;
    final label = Membership.tierLabelOf(tier);
    return until == null
        ? '$label, sans terme'
        : '$label, jusqu’au ${Membership.formatDate(until)}';
  }
}

class ManagedMembershipDialog extends StatefulWidget {
  const ManagedMembershipDialog({required this.user, super.key});

  final AppUser user;

  @override
  State<ManagedMembershipDialog> createState() =>
      _ManagedMembershipDialogState();
}

class _ManagedMembershipDialogState extends State<ManagedMembershipDialog> {
  late MembershipTier _tier;
  late DateTime? _validUntil;
  late final TextEditingController _referenceController;

  AppUser get _user => widget.user;

  @override
  void initState() {
    super.initState();
    _tier = _user.membership.tier;
    _validUntil = _user.membership.validUntil;
    _referenceController = TextEditingController(
      text: _user.membership.reference ?? '',
    );
  }

  @override
  void dispose() {
    _referenceController.dispose();
    super.dispose();
  }

  bool get _isClearing => _tier == MembershipTier.none;

  Future<void> _pickValidUntil() async {
    final now = DateTime.now();
    final firstDate = DateTime(now.year, now.month, now.day + 1);
    // Deux jours de marge sur la limite du callable : la date choisie est
    // ramenée à 23h59, et une échéance au dernier jour exact serait refusée
    // pour quelques heures de trop.
    final lastDate = now.add(Membership.maxValidity - const Duration(days: 2));
    final current = _validUntil;
    final initialDate = (current != null && current.isAfter(firstDate))
        ? (current.isBefore(lastDate) ? current : lastDate)
        : firstDate;

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: 'Échéance des droits',
      cancelText: 'Annuler',
      confirmText: 'Valider',
    );

    if (picked == null) {
      return;
    }

    setState(() {
      // Fin de journée : des droits accordés « jusqu’au 12 » valent tout le 12.
      _validUntil = DateTime(picked.year, picked.month, picked.day, 23, 59);
    });
  }

  void _submit() {
    final reference = _referenceController.text.trim();

    Navigator.of(context).pop(
      MembershipDecision(
        tier: _tier,
        validUntil: _isClearing ? null : _validUntil,
        reference: (_isClearing || reference.isEmpty) ? null : reference,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final current = _user.membership;

    return AlertDialog(
      title: Text('Droits - ${_user.nom}'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Compte cible : ${_user.nom} (${_user.email})'),
              const SizedBox(height: 6),
              Text(
                'État actuel : ${current.statusLabelAt(DateTime.now())}',
                style: const TextStyle(color: AdminTheme.textSecondary),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<MembershipTier>(
                initialValue: _tier,
                decoration: const InputDecoration(
                  labelText: 'Catégorie',
                  border: OutlineInputBorder(),
                ),
                items: Membership.selectableTiers
                    .map(
                      (tier) => DropdownMenuItem<MembershipTier>(
                        value: tier,
                        child: Text(Membership.tierLabelOf(tier)),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }

                  setState(() {
                    _tier = value;
                  });
                },
              ),
              const SizedBox(height: 8),
              Text(
                Membership.tierDescriptionOf(_tier),
                style: AdminType.caption.copyWith(
                  color: AdminTheme.textSecondary,
                ),
              ),
              if (!_isClearing) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _validUntil == null
                            ? 'Échéance : sans terme'
                            : 'Échéance : ${Membership.formatDate(_validUntil!)}',
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _pickValidUntil,
                      icon: const Icon(Icons.event_outlined, size: 18),
                      label: const Text('Choisir'),
                    ),
                    if (_validUntil != null)
                      TextButton(
                        onPressed: () => setState(() => _validUntil = null),
                        child: const Text('Sans terme'),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Un compte sous contrat avec l’agence n’a normalement pas de terme.',
                  style: AdminType.caption.copyWith(
                    color: AdminTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _referenceController,
                  maxLength: Membership.referenceMaxLength,
                  decoration: const InputDecoration(
                    labelText: 'Référence interne (facultatif)',
                    hintText: 'Ex. contrat 2026-014 ou reçu agence 1287',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                _isClearing
                    ? 'Le dossier sera effacé : le compte redeviendra un compte sans droits enregistrés.'
                    : 'Aucun montant n’est enregistré ici. Le règlement se fait à l’agence et cette fiche ne fait qu’en garder la trace.',
                style: AdminType.caption.copyWith(
                  color: AdminTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: Text(_isClearing ? 'Retirer les droits' : 'Enregistrer'),
        ),
      ],
    );
  }
}
