import 'package:cloud_functions/cloud_functions.dart';

import '../config/app_environment.dart';
import '../models/managed_account_provision_result.dart';
import '../models/membership.dart';
import '../utils/account_role_policy.dart';

typedef ManagedAccountCallableExecutor = Future<Map<String, dynamic>> Function(
  String callableName,
  Map<String, dynamic> payload,
);

class ManagedAccountService {
  ManagedAccountService({
    FirebaseFunctions? functions,
    ManagedAccountCallableExecutor? callableExecutor,
  })  : _functions = functions ??
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
        if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
      },
    );

    return ManagedAccountProvisionResult.fromMap(data);
  }

  Future<void> deleteManagedAccount({
    required String uid,
  }) async {
    await _callable(
      'deleteManagedAccount',
      payload: <String, dynamic>{
        'uid': uid,
      },
    );
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
      payload: <String, dynamic>{
        'uid': uid,
        'role': normalizedRole,
      },
    );
  }

  Future<ManagedAccountProvisionResult> resendManagedAccountInvite({
    required String uid,
  }) async {
    final data = await _callable(
      'resendManagedAccountInvite',
      payload: <String, dynamic>{
        'uid': uid,
      },
    );

    return ManagedAccountProvisionResult.fromMap(data);
  }

  Future<void> disableManagedAccountAuth({
    required String uid,
  }) async {
    await _callable(
      'disableManagedAccountAuth',
      payload: <String, dynamic>{
        'uid': uid,
      },
    );
  }

  Future<void> enableManagedAccountAuth({
    required String uid,
  }) async {
    await _callable(
      'enableManagedAccountAuth',
      payload: <String, dynamic>{
        'uid': uid,
      },
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
        "L'échéance doit être dans le futur. Pour retirer un droit, "
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

    await _callable(
      'updateManagedAccountProfile',
      payload: normalizedPayload,
    );
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

    return <String, dynamic>{
      'uid': normalizedUid,
      'patch': normalizedPatch,
    };
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
