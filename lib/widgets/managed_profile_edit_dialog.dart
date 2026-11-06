import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/football_vocabulary.dart';
import '../models/player_football_profile.dart';
import '../models/user.dart';
import '../theme/admin_type.dart';
import '../utils/player_age.dart';
import '../utils/season_record_label.dart';
import 'admin_feedback.dart';
import 'admin_ui.dart';

class ManagedProfileEditDialog extends StatefulWidget {
  const ManagedProfileEditDialog({
    required this.user,
    this.contactLoaded = true,
    super.key,
  });

  final AppUser user;

  /// Si `users/{uid}/private/contact` a pu être lu.
  ///
  /// Faux, le champ date de naissance n'est pas affiché du tout : il ne peut
  /// être ni prérempli ni comparé, et un champ vide dirait le contraire de la
  /// vérité sur une fiche qui porte une date.
  final bool contactLoaded;

  @override
  State<ManagedProfileEditDialog> createState() =>
      _ManagedProfileEditDialogState();
}

class _ManagedProfileEditDialogState extends State<ManagedProfileEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nomController;
  late List<FootballPosition> _positionCodes;

  /// Le parcours tel que l'administration le laissera.
  ///
  /// Le portail retire, il n'ajoute pas : une saison s'archive depuis le
  /// téléphone, au moment où elle se termine, avec le club que le profil
  /// portait alors. Retaper une saison ici reviendrait à saisir de mémoire ce
  /// que l'application savait déjà — et c'est ainsi qu'on invente un fait dans
  /// une base qu'on présente comme qualifiée. Ce qu'un administrateur doit
  /// pouvoir faire, c'est effacer une ligne fausse ou dupliquée.
  late List<SeasonRecord> _seasonHistory;

  /// La date de naissance telle que l'administration la laissera.
  ///
  /// C'est le seul fait dont l'absence retire une fiche de toutes les
  /// recherches : `birthYear` en est dérivé par le serveur, et un dossier sans
  /// année n'est renvoyé à aucun recruteur. Jusqu'ici, seul le joueur pouvait
  /// le réparer, depuis son téléphone.
  DateTime? _birthDate;
  final _guardianNameController = TextEditingController();
  final _guardianEvidenceController = TextEditingController();
  String _guardianRelationship = 'parent';
  String _guardianConsentMethod = 'oral_confirmation';
  bool _guardianConsentConfirmed = false;
  bool _guardianMediaAllowed = false;
  late final TextEditingController _teamController;
  late final TextEditingController _ligueController;
  late final TextEditingController _entrepriseController;
  late final TextEditingController _licenseController;

  AppUser get _user => widget.user;

  @override
  void initState() {
    super.initState();
    _nomController = TextEditingController(text: _user.nom);
    _positionCodes = List<FootballPosition>.of(_user.football.positions);
    _seasonHistory = List<SeasonRecord>.of(_user.football.seasonHistory);
    _birthDate = _user.birthDate;
    // Le club typé, pas `team`. Les deux existaient et personne ne les
    // écrivait ensemble : le portail posait `team`, le formulaire avancé du
    // mobile posait `currentClubName`, et la fiche affichait tantôt l'un
    // tantôt l'autre. Un club corrigé ici ressortait donc à côté de l'ancien
    // sur le téléphone.
    _teamController = TextEditingController(
      text: _user.football.currentClubName ?? '',
    );
    _ligueController = TextEditingController(text: _user.ligue ?? '');
    _entrepriseController = TextEditingController(text: _user.entreprise ?? '');
    _licenseController = TextEditingController(
      text: _currentLicenseNumber() ?? '',
    );
  }

  @override
  void dispose() {
    _nomController.dispose();
    _teamController.dispose();
    _ligueController.dispose();
    _entrepriseController.dispose();
    _licenseController.dispose();
    _guardianNameController.dispose();
    _guardianEvidenceController.dispose();
    super.dispose();
  }

  String? _currentLicenseNumber() {
    if (_user.isPlayer) {
      return _user.playerProfile?['licenseNumber']?.toString();
    }
    if (_user.isClub) {
      return _user.clubProfile?['licenseNumber']?.toString();
    }
    if (_user.isRecruiter) {
      return _user.agentProfile?['licenseNumber']?.toString();
    }
    return null;
  }

  String? _trimOrNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  bool get _isMinor {
    final date = _birthDate;
    if (date == null) {
      return false;
    }
    return isMinorPlayer(date);
  }

  bool get _requiresGuardianConsent =>
      _isMinor &&
      (!_user.isMinorProfile ||
          !_user.minorProfileApproved ||
          !_isSameDay(_birthDate, _user.birthDate));

  Map<String, dynamic> _guardianConsentPayload() => <String, dynamic>{
    'guardianName': _guardianNameController.text.trim(),
    'relationship': _guardianRelationship,
    'method': _guardianConsentMethod,
    'evidenceReference': _guardianEvidenceController.text.trim(),
    'mediaAllowed': _guardianMediaAllowed,
    'confirmed': _guardianConsentConfirmed,
  };

  bool _hasValidGuardianConsent() =>
      _guardianNameController.text.trim().length >= 2 &&
      _guardianConsentConfirmed;

  /// Deux dates désignent-elles le même jour ?
  ///
  /// Comparer les `DateTime` entiers enverrait un patch à chaque ouverture du
  /// dialogue : la valeur relue porte l'heure que le `Timestamp` a conservée,
  /// jamais celle que le sélecteur produit.
  static bool _isSameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) {
      return a == null && b == null;
    }
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  Future<void> _pickBirthDate() async {
    final latestEligibleDate = latestEligibleBirthDate();
    final currentBirthDate = _birthDate;
    final initialDate =
        currentBirthDate == null || currentBirthDate.isAfter(latestEligibleDate)
        ? defaultBirthDatePickerDate()
        : currentBirthDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1930),
      lastDate: latestEligibleDate,
      helpText: 'Date de naissance',
    );

    if (picked == null || !mounted) {
      return;
    }
    setState(() => _birthDate = picked);
  }

  Widget _buildBirthDateField() {
    final value = _birthDate;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                value == null
                    ? 'Date de naissance : non renseignée'
                    : 'Date de naissance : ${_formatDate(value)}',
              ),
            ),
            TextButton.icon(
              onPressed: _pickBirthDate,
              icon: const Icon(Icons.event_outlined, size: 18),
              label: Text(value == null ? 'Renseigner' : 'Modifier'),
            ),
          ],
        ),
        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Sans elle, le dossier n’apparaît dans aucune recherche de '
            'recruteur.',
            style: AdminType.caption,
          ),
        ),
        if (_user.profileVerified) ...[
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Modifier la date retire la certification jusqu’à un nouveau '
              'contrôle : l’âge est un fait que le recruteur croit sur parole.',
              style: AdminType.caption.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ],
    );
  }

  Map<String, dynamic> _buildPatch() {
    final patch = <String, dynamic>{};

    final nom = _nomController.text.trim();
    if (nom.isNotEmpty && nom != _user.nom) {
      patch['nom'] = nom;
    }

    if (_user.isPlayer) {
      // Des codes, pas du texte : `updateManagedAccountProfile` valide contre
      // la meme liste fermee et laisse tomber en silence ce qu'il ne reconnait
      // pas. Un poste tape a la main serait donc perdu sans erreur.
      final codes = _positionCodes.map((p) => p.code).toList();
      final currentCodes = _user.football.positions.map((p) => p.code).toList();
      if (!listEquals(codes, currentCodes)) {
        patch['positionCodes'] = codes;
      }
      final clubName = _trimOrNull(_teamController.text);
      if (clubName != _user.football.currentClubName) {
        patch['currentClubName'] = clubName;
      }
      // ISO-8601, jamais un DateTime : le callable accepte la chaîne, la
      // valide contre `toBirthYear` — celle-là même dont le trigger dérive
      // l'année — et la stocke en `Timestamp`, la forme que le mobile écrit
      // déjà. `null` efface, ce qui est le bon geste pour une date inventée.
      if (widget.contactLoaded && !_isSameDay(_birthDate, _user.birthDate)) {
        patch['birthDate'] = _birthDate?.toIso8601String();
      }
      if (_requiresGuardianConsent && _hasValidGuardianConsent()) {
        patch['guardianConsent'] = _guardianConsentPayload();
      }
      // La liste entière est renvoyée, pas la seule ligne retirée : le
      // callable réécrit `seasonHistory` d'un bloc, et lui envoyer un fragment
      // effacerait le reste du parcours.
      if (_seasonHistory.length != _user.football.seasonHistory.length) {
        patch['seasonHistory'] = _seasonHistory
            .map((season) => season.toMap())
            .toList();
      }
    } else if (_user.isClub) {
      final ligue = _trimOrNull(_ligueController.text);
      if (ligue != _user.ligue) {
        patch['ligue'] = ligue;
      }
      final license = _trimOrNull(_licenseController.text);
      if (license != _currentLicenseNumber()) {
        patch['clubFederationId'] = license;
      }
    } else if (_user.isRecruiter) {
      final entreprise = _trimOrNull(_entrepriseController.text);
      if (entreprise != _user.entreprise) {
        patch['entreprise'] = entreprise;
      }
      final license = _trimOrNull(_licenseController.text);
      if (license != _currentLicenseNumber()) {
        patch['agentProfile'] = {'licenseNumber': license};
      }
    }

    return patch;
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final date = _birthDate;
    if (date != null) {
      final age = playerAgeOn(date);
      if (age < kMinimumPlayerAge) {
        showAdminFeedback(
          title: 'Date de naissance invalide',
          message: 'Adfoot accueille les joueurs à partir de 13 ans.',
          tone: AdminBannerTone.warning,
        );
        return;
      }
      final changed =
          widget.contactLoaded && !_isSameDay(date, _user.birthDate);
      if (changed && age < kAdultAge && !_hasValidGuardianConsent()) {
        showAdminFeedback(
          title: 'Accord parental requis',
          message:
              'Consignez l’accord du parent ou du tuteur avant cette correction.',
          tone: AdminBannerTone.warning,
        );
        return;
      }
    }
    Navigator.of(context).pop(_buildPatch());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Modifier le profil - ${_user.nom}'),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nomController,
                  decoration: const InputDecoration(labelText: 'Nom'),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Le nom est requis.'
                      : null,
                ),
                const SizedBox(height: 12),
                if (_user.isPlayer) ...[
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Postes',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: FootballPosition.values.map((position) {
                      final index = _positionCodes.indexOf(position);
                      final isSelected = index >= 0;
                      final atLimit =
                          _positionCodes.length >=
                          FootballPosition.maxPerPlayer;

                      return FilterChip(
                        selected: isSelected,
                        label: Text(
                          isSelected
                              ? '${index + 1}. ${position.labelFr}'
                              : position.labelFr,
                        ),
                        onSelected: (!isSelected && atLimit)
                            ? null
                            : (_) => setState(() {
                                if (isSelected) {
                                  _positionCodes.remove(position);
                                } else {
                                  _positionCodes.add(position);
                                }
                              }),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _teamController,
                    decoration: const InputDecoration(labelText: 'Club actuel'),
                  ),
                  const SizedBox(height: 12),
                  if (widget.contactLoaded)
                    _buildBirthDateField()
                  else
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Date de naissance indisponible : le document de '
                        'contact n’a pas pu être lu.',
                        style: AdminType.caption,
                      ),
                    ),
                  if (_isMinor) ...[
                    const SizedBox(height: 10),
                    const Text(
                      'Sans accord parental enregistré, la fiche reste masquée. Avec accord, accès limité aux recruteurs vérifiés et contact médié par l’administration.',
                      style: AdminType.caption,
                    ),
                    if (_requiresGuardianConsent) ...[
                      TextFormField(
                        controller: _guardianNameController,
                        decoration: const InputDecoration(
                          labelText: 'Nom du parent ou tuteur',
                        ),
                      ),
                      DropdownButtonFormField<String>(
                        initialValue: _guardianRelationship,
                        decoration: const InputDecoration(
                          labelText: 'Lien avec le joueur',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'parent',
                            child: Text('Parent'),
                          ),
                          DropdownMenuItem(
                            value: 'legal_guardian',
                            child: Text('Tuteur légal'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _guardianRelationship = value);
                          }
                        },
                      ),
                      DropdownButtonFormField<String>(
                        initialValue: _guardianConsentMethod,
                        decoration: const InputDecoration(
                          labelText: 'Mode de consentement vérifié',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'oral_confirmation',
                            child: Text('Accord oral / téléphone'),
                          ),
                          DropdownMenuItem(
                            value: 'written_confirmation',
                            child: Text('Accord écrit'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _guardianConsentMethod = value);
                          }
                        },
                      ),
                      TextFormField(
                        controller: _guardianEvidenceController,
                        decoration: const InputDecoration(
                          labelText: 'Note de suivi (facultatif)',
                        ),
                      ),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _guardianMediaAllowed,
                        title: const Text(
                          'Le parent autorise la publication des photos, vidéos et CV sur la fiche ; les vidéos restent soumises à modération.',
                        ),
                        onChanged: (value) => setState(
                          () => _guardianMediaAllowed = value ?? false,
                        ),
                      ),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _guardianConsentConfirmed,
                        title: const Text(
                          'J’atteste avoir recueilli et consigné l’accord du parent/tuteur.',
                        ),
                        onChanged: (value) => setState(
                          () => _guardianConsentConfirmed = value ?? false,
                        ),
                      ),
                    ] else
                      const Text('Consentement parental déjà enregistré.'),
                  ],
                  if (_seasonHistory.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Parcours',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Retirez une saison fausse ou dupliquée. '
                        'Une saison s’archive depuis l’application.',
                        style: AdminType.caption,
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (final (index, season) in _seasonHistory.indexed)
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              archivedSeasonLabel(season),
                              style: AdminType.body,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Retirer cette saison',
                            icon: const Icon(Icons.close_rounded, size: 18),
                            onPressed: () => setState(
                              () => _seasonHistory = <SeasonRecord>[
                                ..._seasonHistory,
                              ]..removeAt(index),
                            ),
                          ),
                        ],
                      ),
                  ],
                ] else if (_user.isClub) ...[
                  TextFormField(
                    controller: _ligueController,
                    decoration: const InputDecoration(labelText: 'Ligue'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _licenseController,
                    decoration: const InputDecoration(
                      labelText: 'Numéro de licence du club (facultatif)',
                    ),
                  ),
                ] else if (_user.isRecruiter) ...[
                  TextFormField(
                    controller: _entrepriseController,
                    decoration: const InputDecoration(
                      labelText: 'Organisation',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _licenseController,
                    decoration: InputDecoration(
                      labelText: _user.isAgent
                          ? 'Numéro de licence'
                          : 'Référence de licence ou d’agrément',
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        ElevatedButton(onPressed: _submit, child: const Text('Enregistrer')),
      ],
    );
  }
}
