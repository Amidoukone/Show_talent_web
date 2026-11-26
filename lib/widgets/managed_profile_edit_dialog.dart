import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../config/app_environment.dart';
import '../models/football_vocabulary.dart';
import '../models/player_football_profile.dart';
import '../models/user.dart';
import '../services/admin_document_service.dart';
import '../theme/admin_theme.dart';
import '../theme/admin_type.dart';
import '../utils/admin_date_format.dart';
import '../utils/admin_file_picker.dart';
import '../utils/player_age.dart';
import '../utils/season_record_label.dart';
import 'admin_document_preview.dart';
import 'admin_feedback.dart';
import 'admin_ui.dart';

class ManagedProfileEditDialog extends StatefulWidget {
  const ManagedProfileEditDialog({
    required this.user,
    this.contactLoaded = true,
    this.documentService,
    super.key,
  });

  final AppUser user;

  /// Injectable pour les tests.
  final AdminDocumentService? documentService;

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
  late final AdminDocumentService _documentService;

  /// Preuves déjà déposées, `null` tant que la lecture n'a pas répondu.
  List<AdminStoredDocument>? _guardianEvidenceDocuments;
  String? _guardianEvidenceError;
  bool _busyOnGuardianEvidence = false;
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
    // Construit seulement quand ce dialogue en a besoin : la plupart des
    // comptes ne sont jamais mineurs, et `AdminDocumentService()` touche
    // `FirebaseStorage.instance`, indisponible dans les tests qui n'ont
    // jamais eu de raison de s'en soucier jusqu'ici.
    if (_requiresGuardianConsent) {
      _documentService =
          widget.documentService ??
          (AppEnvironmentConfig.visualQaMode
              ? AdminDocumentService.visualQa()
              : AdminDocumentService());
      _loadGuardianEvidence();
    }
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
      return _user.club.federationId ??
          _user.clubProfile?['licenseNumber']?.toString();
    }
    if (_user.isRecruiter) {
      return _user.agent.licenceNumber ??
          _user.agentProfile?['licenseNumber']?.toString();
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

  /// Lit les preuves déjà déposées pour ce compte.
  ///
  /// Un dossier vide n'est pas une erreur : la quasi-totalité des accords
  /// recueillis jusqu'ici sont oraux, sans pièce à déposer.
  Future<void> _loadGuardianEvidence() async {
    try {
      final documents = await _documentService.listGuardianConsentEvidence(
        _user.uid,
      );
      if (!mounted) return;
      setState(() {
        _guardianEvidenceDocuments = documents;
        _guardianEvidenceError = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _guardianEvidenceDocuments = const <AdminStoredDocument>[];
        _guardianEvidenceError =
            'Impossible de lire les justificatifs déjà déposés. Un dépôt '
            'reste possible.';
      });
    }
  }

  Future<void> _openGuardianEvidence(AdminStoredDocument document) async {
    setState(() => _busyOnGuardianEvidence = true);
    final link = await _documentService.resolvePath(document.objectPath);
    if (!mounted) return;
    setState(() => _busyOnGuardianEvidence = false);

    if (!link.success) {
      showAdminFeedback(
        title: 'Ouverture impossible',
        message: link.message,
        tone: AdminBannerTone.danger,
      );
      return;
    }

    await showAdminDocumentPreview(context, link);
  }

  /// Choisit un fichier et le dépose.
  ///
  /// Contrairement à l'accord de club, aucune référence libre ne précède le
  /// dépôt : le nom de l'objet est entièrement fabriqué par
  /// [guardianConsentObjectName], parce que `storage.rules` valide ce nom au
  /// caractère près côté serveur.
  Future<void> _uploadGuardianEvidence() async {
    if (!adminFilePickerSupported) {
      showAdminFeedback(
        title: 'Dépôt indisponible',
        message:
            'Le dépôt de document demande un navigateur. Ouvrez le portail '
            'sur le web pour téléverser un justificatif.',
        tone: AdminBannerTone.warning,
      );
      return;
    }

    final picked = await pickAdminFile(
      accept: '.pdf,.jpg,.jpeg,.png,application/pdf,image/jpeg,image/png',
    );
    if (picked == null || !mounted) return;

    setState(() => _busyOnGuardianEvidence = true);

    final result = await _documentService.uploadGuardianConsentEvidence(
      uid: _user.uid,
      file: picked,
    );

    if (!mounted) return;
    setState(() => _busyOnGuardianEvidence = false);

    showAdminFeedback(
      title: result.success ? 'Justificatif déposé' : 'Dépôt impossible',
      message: result.message,
      tone: result.success ? AdminBannerTone.success : AdminBannerTone.danger,
    );

    if (result.success) {
      await _loadGuardianEvidence();
    }
  }

  String _formatEvidenceSize(int? bytes) {
    if (bytes == null) return '';
    if (bytes < 1024) return '$bytes o';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} Ko';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} Mo';
  }

  /// Le bloc des justificatifs déposés : ce qui existe déjà, et un dépôt.
  Widget _buildGuardianEvidenceDocuments() {
    final documents = _guardianEvidenceDocuments;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (documents == null)
          const Text('Lecture du dossier…', style: AdminType.caption)
        else if (documents.isEmpty)
          const Text(
            'Aucun justificatif déposé. La note ci-dessus suffit à '
            'enregistrer l’accord ; déposer le document permet de le '
            'relire plus tard.',
            style: AdminType.caption,
          )
        else
          for (final document in documents)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  const Icon(
                    Icons.description_outlined,
                    size: 14,
                    color: AdminTheme.cyan,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      document.updatedAt == null
                          ? document.name
                          : '${document.name} · '
                                '${formatAdminDate(document.updatedAt!)}'
                                '${document.sizeBytes == null ? '' : ' · ${_formatEvidenceSize(document.sizeBytes)}'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AdminType.caption,
                    ),
                  ),
                  TextButton(
                    onPressed: _busyOnGuardianEvidence
                        ? null
                        : () => _openGuardianEvidence(document),
                    child: const Text('Ouvrir'),
                  ),
                ],
              ),
            ),
        if (_guardianEvidenceError != null) ...[
          const SizedBox(height: 4),
          Text(
            _guardianEvidenceError!,
            style: AdminType.caption.copyWith(color: AdminTheme.warning),
          ),
        ],
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _busyOnGuardianEvidence ? null : _uploadGuardianEvidence,
          icon: const Icon(Icons.upload_file_outlined),
          label: Text(
            _busyOnGuardianEvidence
                ? 'Dépôt en cours…'
                : 'Déposer un justificatif',
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'PDF ou photo, 8 Mo au plus. Le dossier est en lecture et en '
          'écriture pour l’administration seule.',
          style: AdminType.caption,
        ),
      ],
    );
  }

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
    setState(
      () => _birthDate = DateTime.utc(picked.year, picked.month, picked.day),
    );
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
        final date = _birthDate;
        patch['birthDate'] = date == null
            ? null
            : DateTime.utc(date.year, date.month, date.day).toIso8601String();
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
        patch['agentLicenceNumber'] = license;
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
                if (_user.profileVerified) ...[
                  Text(
                    'Ce profil est certifié : modifier les informations '
                    'd’identité, de date de naissance, de poste, de club, de '
                    'parcours ou de licence retire la certification jusqu’à un '
                    'nouveau contrôle.',
                    style: AdminType.caption.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
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
                      const SizedBox(height: 8),
                      _buildGuardianEvidenceDocuments(),
                      const SizedBox(height: 4),
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
