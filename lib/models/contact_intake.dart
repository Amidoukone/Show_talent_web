import 'package:cloud_firestore/cloud_firestore.dart';

class ContactContextType {
  ContactContextType._();

  static const String none = 'none';
  static const String profile = 'profile';
  static const String event = 'event';
  static const String participants = 'participants';
  static const String discovery = 'discovery';
  static const String offer = 'offer';

  static String normalize(String? value) {
    switch (value?.trim().toLowerCase()) {
      case profile:
        return profile;
      case event:
        return event;
      case participants:
        return participants;
      case discovery:
        return discovery;
      case offer:
        return offer;
      default:
        return none;
    }
  }

  static String label(String? value) {
    switch (normalize(value)) {
      case profile:
        return 'Profil';
      case event:
        return 'Evenement';
      case participants:
        return 'Participants';
      case discovery:
        return 'Decouverte';
      case offer:
        return 'Offre';
      default:
        return 'Contact';
    }
  }
}

class ContactReasonCode {
  ContactReasonCode._();

  static const String opportunity = 'opportunity';
  static const String trial = 'trial';
  static const String application = 'application';
  static const String followUp = 'follow_up';
  static const String information = 'information';

  static String normalize(String? value) {
    switch (value?.trim().toLowerCase()) {
      case opportunity:
        return opportunity;
      case trial:
        return trial;
      case application:
        return application;
      case followUp:
        return followUp;
      default:
        return information;
    }
  }

  static String label(String? value) {
    switch (normalize(value)) {
      case opportunity:
        return 'Opportunite';
      case trial:
        return 'Essai / Evaluation';
      case application:
        return 'Candidature / Presentation';
      case followUp:
        return 'Suivi';
      default:
        return 'Information';
    }
  }
}

class AgencyFollowUpStatus {
  AgencyFollowUpStatus._();

  static const String newLead = 'new';
  static const String reviewing = 'reviewing';
  static const String inProgress = 'in_progress';
  static const String qualified = 'qualified';
  static const String closed = 'closed';

  static const List<String> values = <String>[
    newLead,
    reviewing,
    inProgress,
    qualified,
    closed,
  ];

  static String normalize(String? value) {
    switch (value?.trim().toLowerCase()) {
      case reviewing:
        return reviewing;
      case inProgress:
        return inProgress;
      case qualified:
        return qualified;
      case closed:
        return closed;
      case newLead:
      default:
        return newLead;
    }
  }

  static String label(String? value) {
    switch (normalize(value)) {
      case reviewing:
        return 'En revue';
      case inProgress:
        return 'En accompagnement';
      case qualified:
        return 'Qualifie';
      case closed:
        return 'Clos';
      case newLead:
      default:
        return 'Nouveau lead';
    }
  }
}

class ContactIntake {
  const ContactIntake({
    required this.id,
    required this.requesterUid,
    required this.targetUid,
    required this.requesterRole,
    required this.targetRole,
    required this.contextType,
    required this.contactReason,
    required this.introMessage,
    required this.status,
    required this.agencyFollowUpStatus,
    this.agencyFollowUpNote,
    this.agencyLastUpdatedByUid,
    this.agencyLastUpdatedAt,
    this.conversationId,
    this.contextId,
    this.contextTitle,
    this.requesterSnapshot,
    this.targetSnapshot,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String requesterUid;
  final String targetUid;
  final String requesterRole;
  final String targetRole;
  final String contextType;
  final String contactReason;
  final String introMessage;
  final String status;
  final String agencyFollowUpStatus;
  final String? agencyFollowUpNote;
  final String? agencyLastUpdatedByUid;
  final DateTime? agencyLastUpdatedAt;
  final String? conversationId;
  final String? contextId;
  final String? contextTitle;
  final Map<String, dynamic>? requesterSnapshot;
  final Map<String, dynamic>? targetSnapshot;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory ContactIntake.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    return ContactIntake.fromMap(doc.data() ?? const <String, dynamic>{},
        fallbackId: doc.id);
  }

  factory ContactIntake.fromMap(
    Map<String, dynamic> map, {
    String? fallbackId,
  }) {
    final rawId = map['id']?.toString().trim() ?? '';
    final resolvedId = rawId.isNotEmpty ? rawId : (fallbackId ?? '');

    return ContactIntake(
      id: resolvedId,
      requesterUid: map['requesterUid']?.toString() ?? '',
      targetUid: map['targetUid']?.toString() ?? '',
      requesterRole: map['requesterRole']?.toString() ?? '',
      targetRole: map['targetRole']?.toString() ?? '',
      contextType: ContactContextType.normalize(map['contextType']?.toString()),
      contactReason: ContactReasonCode.normalize(
        map['contactReason']?.toString(),
      ),
      introMessage: map['introMessage']?.toString() ?? '',
      status: map['status']?.toString() ?? 'new',
      agencyFollowUpStatus: AgencyFollowUpStatus.normalize(
        map['agencyFollowUpStatus']?.toString(),
      ),
      agencyFollowUpNote: _normalizeNullableString(map['agencyFollowUpNote']),
      agencyLastUpdatedByUid:
          _normalizeNullableString(map['agencyLastUpdatedByUid']),
      agencyLastUpdatedAt: _parseNullableDate(map['agencyLastUpdatedAt']),
      conversationId: _normalizeNullableString(map['conversationId']),
      contextId: _normalizeNullableString(map['contextId']),
      contextTitle: _normalizeNullableString(map['contextTitle']),
      requesterSnapshot: _normalizeMap(map['requesterSnapshot']),
      targetSnapshot: _normalizeMap(map['targetSnapshot']),
      createdAt: _parseNullableDate(map['createdAt']),
      updatedAt: _parseNullableDate(map['updatedAt']),
    );
  }

  String get requesterDisplayName =>
      _resolveNameFromSnapshot(requesterSnapshot) ?? requesterUid;

  String get targetDisplayName =>
      _resolveNameFromSnapshot(targetSnapshot) ?? targetUid;

  String? get requesterOrganization => _resolveOrganization(requesterSnapshot);

  String? get targetOrganization => _resolveOrganization(targetSnapshot);

  String get requesterRoleLabel => _roleLabel(requesterRole);

  String get targetRoleLabel => _roleLabel(targetRole);

  String get reasonLabel => ContactReasonCode.label(contactReason);

  String get contextLabel => ContactContextType.label(contextType);

  String get followUpLabel => AgencyFollowUpStatus.label(agencyFollowUpStatus);

  bool get hasAgencyNote => agencyFollowUpNote?.trim().isNotEmpty == true;

  static String _roleLabel(String rawRole) {
    switch (rawRole.trim().toLowerCase()) {
      case 'club':
        return 'Club';
      case 'recruteur':
        return 'Recruteur';
      case 'agent':
        return 'Agent';
      case 'joueur':
        return 'Joueur';
      case 'fan':
        return 'Fan';
      case 'admin':
        return 'Admin';
      default:
        return rawRole.trim().isEmpty ? 'Compte' : rawRole.trim();
    }
  }

  static String? _resolveNameFromSnapshot(Map<String, dynamic>? snapshot) {
    if (snapshot == null) {
      return null;
    }

    final displayName = _normalizeNullableString(snapshot['displayName']);
    if (displayName != null) {
      return displayName;
    }

    final firstName = _normalizeNullableString(snapshot['prenom']);
    final lastName = _normalizeNullableString(snapshot['nom']);
    final combined = [firstName, lastName]
        .whereType<String>()
        .where((value) => value.trim().isNotEmpty)
        .join(' ')
        .trim();
    if (combined.isNotEmpty) {
      return combined;
    }

    return lastName;
  }

  static String? _resolveOrganization(Map<String, dynamic>? snapshot) {
    if (snapshot == null) {
      return null;
    }

    return _normalizeNullableString(snapshot['organisation']) ??
        _normalizeNullableString(snapshot['organization']) ??
        _normalizeNullableString(snapshot['club']);
  }

  static Map<String, dynamic>? _normalizeMap(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return null;
  }

  static String? _normalizeNullableString(dynamic value) {
    final normalized = value?.toString().trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }

  static DateTime? _parseNullableDate(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }

    if (value is String) {
      return DateTime.tryParse(value);
    }

    return null;
  }
}
