class ManagedAccountProvisionResult {
  final String uid;
  final String email;
  final String role;
  final bool existingUser;
  final String? passwordSetupLink;
  final String? emailVerificationLink;

  /// Whether the backend e-mailed the invitation itself.
  ///
  /// Defaults to false, which is also what an older backend — one that never
  /// sends anything — produces. The links below are returned either way, so
  /// this only ever adds information: it never takes away the copy-paste
  /// workflow this dialog was built around.
  final bool inviteEmailSent;

  /// Coarse reason the invitation was not sent (`not_configured`,
  /// `send_failed`, `invalid_recipient`), or null when it was.
  final String? inviteEmailReason;

  const ManagedAccountProvisionResult({
    required this.uid,
    required this.email,
    required this.role,
    required this.existingUser,
    this.passwordSetupLink,
    this.emailVerificationLink,
    this.inviteEmailSent = false,
    this.inviteEmailReason,
  });

  factory ManagedAccountProvisionResult.fromMap(Map<String, dynamic> map) {
    final payload = _extractPayload(map);
    return ManagedAccountProvisionResult(
      uid: payload['uid']?.toString() ?? '',
      email: payload['email']?.toString() ?? '',
      role: payload['role']?.toString() ?? '',
      existingUser: payload['existingUser'] == true,
      passwordSetupLink: _readOptionalString(payload['passwordSetupLink']),
      emailVerificationLink:
          _readOptionalString(payload['emailVerificationLink']),
      inviteEmailSent: payload['inviteEmailSent'] == true,
      inviteEmailReason: _readOptionalString(payload['inviteEmailReason']),
    );
  }

  /// What to tell the admin about the automatic send, in their own terms.
  ///
  /// Silence here was the bug worth avoiding: an admin who is told nothing
  /// assumes the member was contacted, and the member waits for a message
  /// that never left.
  String get inviteEmailStatusMessage {
    if (inviteEmailSent) {
      return 'L’invitation a été envoyée automatiquement à $email. '
          'Les liens ci-dessous restent disponibles en secours.';
    }

    switch (inviteEmailReason) {
      case 'not_configured':
        return 'L’envoi automatique n’est pas configuré sur le serveur. '
            'Transmettez le lien ci-dessous au titulaire.';
      case 'invalid_recipient':
        return 'L’adresse e-mail a été refusée par le serveur d’envoi. '
            'Vérifiez-la, puis transmettez le lien ci-dessous.';
      case 'send_failed':
        return 'L’envoi automatique a échoué. '
            'Transmettez le lien ci-dessous au titulaire.';
      default:
        return 'Aucun e-mail n’a été envoyé automatiquement. '
            'Transmettez le lien ci-dessous au titulaire.';
    }
  }

  bool get hasPasswordSetupLink => passwordSetupLink != null;

  bool get requiresEmailVerification => emailVerificationLink != null;

  String get lifecycleLabel => existingUser
      ? 'utilisateur existant mis à jour'
      : 'nouveau compte géré créé';

  List<String> buildRecommendedSteps({
    String appName = 'Adfoot',
  }) {
    final steps = <String>[];

    if (requiresEmailVerification) {
      steps.add("Ouvrir d’abord le lien de validation d’e-mail.");
      steps.add("Confirmer l’adresse e-mail avant la première connexion.");
    } else {
      steps.add("L’e-mail est déjà vérifié. La connexion peut se faire ensuite.");
    }

    if (hasPasswordSetupLink) {
      steps.add('Ouvrir ensuite le lien de définition du mot de passe.');
      steps.add('Choisir puis enregistrer le nouveau mot de passe.');
    } else {
      steps.add(
        'Contacter l’administration pour récupérer le lien de définition du mot de passe.',
      );
    }

    if (email.isNotEmpty) {
      steps.add('Se connecter enfin dans $appName avec l’adresse $email.');
    } else {
      steps.add('Se connecter enfin dans $appName avec l’adresse transmise.');
    }

    return steps;
  }

  String buildInviteMessage({
    String? recipientName,
    String appName = 'Adfoot',
  }) {
    return buildEmailMessage(
      recipientName: recipientName,
      appName: appName,
    );
  }

  String buildWhatsappMessage({
    String? recipientName,
    String appName = 'Adfoot',
  }) {
    final trimmedRecipient = recipientName?.trim() ?? '';
    final lines = <String>[
      trimmedRecipient.isEmpty ? 'Bonjour,' : 'Bonjour $trimmedRecipient,',
      '',
      'Votre compte $role $appName est prêt.',
      '',
      'À faire dans cet ordre :',
    ];

    if (requiresEmailVerification) {
      lines
        ..add('1. Valider votre e-mail :')
        ..add(emailVerificationLink!)
        ..add('')
        ..add('2. Définir votre mot de passe :')
        ..add(
          passwordSetupLink ?? 'Lien indisponible, contacter l’administration.',
        )
        ..add('')
        ..add('3. Vous connecter avec :')
        ..add(email.isNotEmpty ? email : 'Adresse non renseignée')
        ..add('')
        ..add('Important : faites bien les étapes dans cet ordre.');
    } else {
      lines
        ..add('1. Définir votre mot de passe :')
        ..add(
          passwordSetupLink ?? 'Lien indisponible, contacter l’administration.',
        )
        ..add('')
        ..add('2. Vous connecter avec :')
        ..add(email.isNotEmpty ? email : 'Adresse non renseignée')
        ..add('')
        ..add('Votre e-mail est déjà validé.');
    }

    return lines.join('\n');
  }

  String buildEmailSubject({
    String appName = 'Adfoot',
  }) {
    return existingUser
        ? 'Réactivation de votre compte $role $appName'
        : 'Activation de votre compte $role $appName';
  }

  String buildEmailMessage({
    String? recipientName,
    String appName = 'Adfoot',
  }) {
    final trimmedRecipient = recipientName?.trim() ?? '';
    final lines = <String>[
      trimmedRecipient.isEmpty ? 'Bonjour,' : 'Bonjour $trimmedRecipient,',
      '',
      existingUser
          ? 'Votre compte $role $appName a été mis à jour.'
          : 'Votre compte $role $appName a été créé.',
      '',
      'Merci de suivre ces étapes dans l’ordre :',
      '',
    ];

    if (requiresEmailVerification) {
      lines
        ..add(
          '1. Ouvrez le lien ci-dessous pour valider votre adresse e-mail :',
        )
        ..add(emailVerificationLink!)
        ..add('')
        ..add('2. Ouvrez ensuite ce lien pour définir votre mot de passe :')
        ..add(
          passwordSetupLink ?? 'Lien indisponible, contacter l’administration.',
        )
        ..add('')
        ..add(
          '3. Une fois ces deux étapes terminées, connectez-vous à l’application avec cette adresse :',
        );
    } else {
      lines
        ..add('1. Ouvrez le lien ci-dessous pour définir votre mot de passe :')
        ..add(
          passwordSetupLink ?? 'Lien indisponible, contacter l’administration.',
        )
        ..add('')
        ..add(
          '2. Ensuite, connectez-vous à l’application avec cette adresse :',
        );
    }

    lines
      ..add(email.isNotEmpty ? email : 'Adresse non renseignée')
      ..add('')
      ..add(
        requiresEmailVerification
            ? "Important : commencez bien par la validation de l’e-mail, puis le mot de passe."
            : "Aucune validation supplémentaire de l’e-mail n’est nécessaire.",
      )
      ..add('')
      ..add('Cordialement,')
      ..add('L’administration $appName');

    return lines.join('\n');
  }

  static Map<String, dynamic> _extractPayload(Map<String, dynamic> map) {
    final nestedData = map['data'];
    if (nestedData is Map<String, dynamic>) {
      return nestedData;
    }
    if (nestedData is Map) {
      return Map<String, dynamic>.from(nestedData);
    }
    return map;
  }

  static String? _readOptionalString(dynamic value) {
    if (value == null) {
      return null;
    }

    final normalized = value.toString().trim();
    return normalized.isEmpty ? null : normalized;
  }
}
