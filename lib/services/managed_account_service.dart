import 'package:cloud_functions/cloud_functions.dart';

import '../models/managed_account_provision_result.dart';
import '../utils/account_role_policy.dart';

class ManagedAccountService {
  ManagedAccountService({FirebaseFunctions? functions})
      : _functions = functions ??
            FirebaseFunctions.instanceFor(region: _functionsRegion);

  final FirebaseFunctions _functions;
  static const String _functionsRegion = 'europe-west1';
  static const Set<String> _managedProfileTransportKeys = {
    'uid',
    'patch',
    'data',
  };

  Future<Map<String, dynamic>> _callable(
    String callableName, {
    required Map<String, dynamic> payload,
  }) async {
    final callable = _functions.httpsCallable(callableName);
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

    if (!isManagedAccountRole(normalizedRole)) {
      throw ArgumentError.value(
        role,
        'role',
        'Le rôle doit être l’un de ${managedAccountRoles.join(', ')}.',
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

    if (!isManagedAccountRole(normalizedRole)) {
      throw ArgumentError.value(
        role,
        'role',
        'Le rôle doit être l’un de ${managedAccountRoles.join(', ')}.',
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
