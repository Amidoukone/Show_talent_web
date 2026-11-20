import 'package:cloud_functions/cloud_functions.dart';

import '../config/app_environment.dart';
import '../models/club_enrollment.dart';
import '../models/managed_account_provision_result.dart';
import '../models/admin_action_response.dart';
import '../models/membership.dart';
import '../utils/account_role_policy.dart';

typedef ManagedAccountCallableExecutor =
    Future<Map<String, dynamic>> Function(
      String callableName,
      Map<String, dynamic> payload,
    );

class ManagedAccountService {
  ManagedAccountService({
    FirebaseFunctions? functions,
    ManagedAccountCallableExecutor? callableExecutor,
  }) : _functions =
           functions ??
           (callableExecutor == null && !AppEnvironmentConfig.visualQaMode
               ? FirebaseFunctions.instanceFor(
                   region: AppEnvironmentConfig.functionsRegion,
                 )
               : null),
       _callableExecutor = callableExecutor;

  final FirebaseFunctions? _functions;
  final ManagedAccountCallableExecutor? _callableExecutor;

  static const Set<String> _managedProfileTransportKeys = {
    'uid',
    'patch',
    'data',
  };

  Future<Map<String, dynamic>> _callable(
    String callableName, {
    required Map<String, dynamic> payload,
  }) async {
    if (_callableExecutor != null) {
      return _callableExecutor(callableName, payload);
    }

    final functions = _functions;
    if (functions == null) {
      throw StateError('FirebaseFunctions n’est pas configuré.');
    }

    final callable = functions.httpsCallable(callableName);
    final response = await callable.call(payload);
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<ManagedAccountProvisionResult> provisionManagedAccount({
    required String email,
    required String nom,
    required String role,
    String? phone,
    DateTime? birthDate,
    Map<String, dynamic>? guardianConsent,
  }) async {
    final normalizedRole = normalizeUserRole(role);

    if (!isAdminProvisionedRole(normalizedRole)) {
      throw ArgumentError.value(
        role,
        'role',
        'Le rôle doit être l’un de ${adminProvisionedRoles.join(', ')}.',
      );
    }

    final data = await _callable(
      'provisionManagedAccount',
      payload: <String, dynamic>{
        'email': email.trim(),
        'nom': nom.trim(),
        'role': normalizedRole,
        if (phone case final value? when value.trim().isNotEmpty)
          'phone': value.trim(),
        if (birthDate case final value?)
          'birthDate': value.toUtc().toIso8601String(),
        'guardianConsent': guardianConsent,
      },
    );

    return ManagedAccountProvisionResult.fromMap(data);
  }

  Future<AdminActionResponse> deleteManagedAccount({
    required String uid,
  }) async {
    final result = await _callable(
      'deleteManagedAccount',
      payload: <String, dynamic>{'uid': uid},
    );
    return AdminActionResponse.fromMap(result);
  }

  Future<void> changeManagedAccountRole({
    required String uid,
    required String role,
  }) async {
    final normalizedRole = normalizeUserRole(role);

    if (!isAdminProvisionedRole(normalizedRole)) {
      throw ArgumentError.value(
        role,
        'role',
        'Le rôle doit être l’un de ${adminProvisionedRoles.join(', ')}.',
      );
    }

    await _callable(
      'changeManagedAccountRole',
      payload: <String, dynamic>{'uid': uid, 'role': normalizedRole},
    );
  }

  Future<ManagedAccountProvisionResult> resendManagedAccountInvite({
    required String uid,
  }) async {
    final data = await _callable(
      'resendManagedAccountInvite',
      payload: <String, dynamic>{'uid': uid},
    );

    return ManagedAccountProvisionResult.fromMap(data);
  }

  Future<void> disableManagedAccountAuth({required String uid}) async {
    await _callable(
      'disableManagedAccountAuth',
      payload: <String, dynamic>{'uid': uid},
    );
  }

  Future<void> enableManagedAccountAuth({required String uid}) async {
    await _callable(
      'enableManagedAccountAuth',
      payload: <String, dynamic>{'uid': uid},
    );
  }

  /// Enregistre — ou retire — les droits d'un compte suivi par l'agence.
  ///
  /// Appel dédié plutôt qu'un champ de [updateManagedAccountProfile] : ce
  /// dernier invalide la certification du profil, et enregistrer un règlement
  /// ne doit pas coûter son badge à un joueur.
  ///
  /// Aucun montant ne transite ici : le règlement a lieu hors de la
  /// plateforme et cet appel ne fait qu'en enregistrer le résultat.
  /// [validUntil] est facultatif — un joueur sous contrat n'a pas de terme —
  /// et [reference] reçoit la référence interne du règlement ou du contrat.
  Future<void> setManagedAccountMembership({
    required String uid,
    required MembershipTier tier,
    DateTime? validUntil,
    String? reference,
  }) async {
    final normalizedUid = uid.trim();
    if (normalizedUid.isEmpty) {
      throw ArgumentError(
        'setManagedAccountMembership requiert un uid non vide.',
      );
    }

    // tier: none efface le dossier. Envoyer une échéance ou une référence
    // avec serait au mieux ignoré côté backend, au pire trompeur dans le
    // journal d'appels : on ne les transmet pas.
    if (tier == MembershipTier.none) {
      await _callable(
        'setManagedAccountMembership',
        payload: <String, dynamic>{
          'uid': normalizedUid,
          'tier': Membership.tierToString(MembershipTier.none),
        },
      );
      return;
    }

    if (validUntil != null && !validUntil.isAfter(DateTime.now())) {
      throw ArgumentError.value(
        validUntil,
        'validUntil',
        "L’échéance doit être dans le futur. Pour retirer un droit, "
            'utilisez MembershipTier.none.',
      );
    }

    final normalizedReference = reference?.trim();

    await _callable(
      'setManagedAccountMembership',
      payload: <String, dynamic>{
        'uid': normalizedUid,
        'tier': Membership.tierToString(tier),
        if (validUntil != null)
          'validUntil': validUntil.toUtc().toIso8601String(),
        if (normalizedReference != null && normalizedReference.isNotEmpty)
          'reference': normalizedReference,
      },
    );
  }

  /// Retire tout dossier de droits du compte.
  Future<void> clearManagedAccountMembership({required String uid}) {
    return setManagedAccountMembership(uid: uid, tier: MembershipTier.none);
  }

  /// Habilite un club à déclarer ses joueurs, contre un accord signé.
  ///
  /// Distinct de [setManagedAccountMembership], et la distinction est le fond
  /// du sujet : l'enrôlement ne s'achète pas. Un club qui déclare quarante
  /// joueurs fait le travail de saisie à la place d'Adfoot, là où l'abonnement
  /// achète de publier, chercher et recevoir des mises en relation. Les deux
  /// ne se conditionnent jamais l'un l'autre.
  ///
  /// [agreementRef] et [validUntil] sont tous deux obligatoires, le callable
  /// les exige. Une habilitation pointe vers l'accord qui a été signé, parce
  /// que tous les clubs n'ont pas le même, et elle a un terme, parce qu'un
  /// droit que personne ne revisite finit par survivre à l'accord qu'il
  /// représente.
  ///
  /// Ce service n'accorde que. Pour retirer, voir [revokeClubEnrollment] : le
  /// retrait doit aussi traiter ce que le club a déjà déclaré, et le callable
  /// refuse explicitement un `granted: false` envoyé ici.
  Future<void> grantClubEnrollment({
    required String uid,
    required String agreementRef,
    required DateTime validUntil,
  }) async {
    final normalizedUid = uid.trim();
    if (normalizedUid.isEmpty) {
      throw ArgumentError('grantClubEnrollment requiert un uid non vide.');
    }

    final normalizedReference = agreementRef.trim();
    if (normalizedReference.isEmpty) {
      throw ArgumentError(
        "La référence de l'accord signé est requise : l'habilitation doit "
        'pointer vers un accord.',
      );
    }

    if (!ClubEnrollment.isGrantDateValid(validUntil)) {
      throw ArgumentError.value(
        validUntil,
        'validUntil',
        "L'échéance doit être dans le futur, dans la limite de cinq ans.",
      );
    }

    await _callable(
      'setClubEnrollmentRight',
      payload: <String, dynamic>{
        'uid': normalizedUid,
        'granted': true,
        'agreementRef': normalizedReference,
        'validUntil': validUntil.toUtc().toIso8601String(),
      },
    );
  }

  /// Retire l'habilitation d'un club, et traite ce qu'il a déjà déclaré.
  ///
  /// C'est le levier qui rend la délégation sûre : habiliter des clubs à créer
  /// des comptes sans pouvoir revenir dessus serait un chèque en blanc.
  ///
  /// Trois traitements, côté serveur. Une déclaration non confirmée est
  /// annulée, elle n'a jamais commencé. Une affiliation confirmée n'est pas
  /// défaite, le joueur l'ayant acceptée, mais elle est signalée pour réexamen
  /// et la fiche cesse d'être présentée comme adossée à un club habilité. Une
  /// contestation est laissée à l'administration, qui l'examinait déjà.
  ///
  /// Seule porte de retrait, volontairement : deux chemins dont un seul
  /// applique la cascade se paient une fois en production.
  Future<AdminActionResponse> revokeClubEnrollment({
    required String uid,
    String? reason,
  }) async {
    final normalizedUid = uid.trim();
    if (normalizedUid.isEmpty) {
      throw ArgumentError('revokeClubEnrollment requiert un uid non vide.');
    }

    final normalizedReason = reason?.trim();

    final result = await _callable(
      'revokeClubEnrollment',
      payload: <String, dynamic>{
        'uid': normalizedUid,
        if (normalizedReason != null && normalizedReason.isNotEmpty)
          'reason': normalizedReason,
      },
    );
    return AdminActionResponse.fromMap(result);
  }

  /// Applies a verified parent or guardian request to withdraw permissions.
  Future<void> withdrawManagedMinorConsent({required String uid}) async {
    final normalizedUid = uid.trim();
    if (normalizedUid.isEmpty) {
      throw ArgumentError('withdrawManagedMinorConsent requires a uid.');
    }
    await _callable(
      'withdrawManagedMinorConsent',
      payload: <String, dynamic>{'uid': normalizedUid},
    );
  }

  Future<void> updateManagedAccountProfile({
    String? uid,
    Map<String, dynamic>? profileData,
    Map<String, dynamic>? patch,
    Map<String, dynamic>? data,
    Map<String, dynamic>? payload,
  }) async {
    final normalizedPayload = _normalizeManagedAccountProfilePayload(
      uid: uid,
      profileData: profileData,
      patch: patch,
      data: data,
      payload: payload,
    );

    await _callable('updateManagedAccountProfile', payload: normalizedPayload);
  }

  Future<void> verifyManagedAccountProfile({
    required String uid,
    String? note,
  }) {
    final normalizedNote = note?.trim();

    return updateManagedAccountProfile(
      uid: uid,
      patch: <String, dynamic>{
        'profileVerified': true,
        'profileVerificationStatus': 'verified',
        if (normalizedNote != null && normalizedNote.isNotEmpty)
          'profileVerificationNote': normalizedNote,
      },
    );
  }

  Future<void> unverifyManagedAccountProfile({
    required String uid,
    String? note,
  }) {
    final normalizedNote = note?.trim();

    return updateManagedAccountProfile(
      uid: uid,
      patch: <String, dynamic>{
        'profileVerified': false,
        'profileVerificationStatus': 'unverified',
        if (normalizedNote != null && normalizedNote.isNotEmpty)
          'profileVerificationNote': normalizedNote,
      },
    );
  }

  Map<String, dynamic> _normalizeManagedAccountProfilePayload({
    String? uid,
    Map<String, dynamic>? profileData,
    Map<String, dynamic>? patch,
    Map<String, dynamic>? data,
    Map<String, dynamic>? payload,
  }) {
    final envelope = <String, dynamic>{};

    if (payload != null) {
      envelope.addAll(payload);
    }

    if (profileData != null) {
      envelope.addAll(profileData);
    }

    final normalizedUid = _resolveManagedAccountProfileUid(
      explicitUid: uid,
      envelope: envelope,
    );

    final normalizedPatch = _resolveManagedAccountProfilePatch(
      explicitPatch: patch,
      explicitData: data,
      envelope: envelope,
    );

    return <String, dynamic>{'uid': normalizedUid, 'patch': normalizedPatch};
  }

  String _resolveManagedAccountProfileUid({
    required String? explicitUid,
    required Map<String, dynamic> envelope,
  }) {
    final candidate = explicitUid ?? envelope['uid']?.toString();
    final normalizedUid = candidate?.trim() ?? '';

    if (normalizedUid.isEmpty) {
      throw ArgumentError(
        'updateManagedAccountProfile requiert un uid non vide.',
      );
    }

    return normalizedUid;
  }

  Map<String, dynamic> _resolveManagedAccountProfilePatch({
    required Map<String, dynamic>? explicitPatch,
    required Map<String, dynamic>? explicitData,
    required Map<String, dynamic> envelope,
  }) {
    if (explicitPatch != null) {
      return Map<String, dynamic>.from(explicitPatch);
    }

    if (explicitData != null) {
      return Map<String, dynamic>.from(explicitData);
    }

    final patchFromEnvelope = envelope['patch'];
    if (patchFromEnvelope != null) {
      if (patchFromEnvelope is! Map) {
        throw ArgumentError(
          'Le champ patch doit être un objet Map<String, dynamic>.',
        );
      }

      return Map<String, dynamic>.from(patchFromEnvelope);
    }

    final dataFromEnvelope = envelope['data'];
    if (dataFromEnvelope != null) {
      if (dataFromEnvelope is! Map) {
        throw ArgumentError(
          'Le champ data doit être un objet Map<String, dynamic>.',
        );
      }

      return Map<String, dynamic>.from(dataFromEnvelope);
    }

    final flatPatch = Map<String, dynamic>.from(envelope)
      ..removeWhere((key, _) => _managedProfileTransportKeys.contains(key));

    return flatPatch;
  }
}
