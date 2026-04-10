class ManagedAccountProvisionResult {
  final String uid;
  final String email;
  final String role;
  final bool existingUser;
  final String? passwordSetupLink;
  final String? emailVerificationLink;

  const ManagedAccountProvisionResult({
    required this.uid,
    required this.email,
    required this.role,
    required this.existingUser,
    this.passwordSetupLink,
    this.emailVerificationLink,
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
    );
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

    if (hasPasswordSetupLink) {
      steps.add('Ouvrir d’abord le lien de définition du mot de passe.');
      steps.add('Choisir puis enregistrer le nouveau mot de passe.');
    } else {
      steps.add(
        'Contacter l’administration pour récupérer le lien de définition du mot de passe.',
      );
    }

    if (requiresEmailVerification) {
      steps.add('Ouvrir ensuite le lien de validation d’e-mail.');
      steps.add('Confirmer l’adresse e-mail avant la première connexion.');
    } else {
      steps.add(
          'L’e-mail est déjà vérifié. La connexion peut se faire ensuite.');
    }

    if (email.isNotEmpty) {
      steps.add(
        'Se connecter enfin dans $appName avec l’adresse $email.',
      );
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
      '1. Définir votre mot de passe :',
      passwordSetupLink ?? 'Lien indisponible, contacter l’administration.',
    ];

    if (requiresEmailVerification) {
      lines
        ..add('')
        ..add('2. Valider votre e-mail :')
        ..add(emailVerificationLink!);
    } else {
      lines
        ..add('')
        ..add('2. Vous connecter avec :')
        ..add(email.isNotEmpty ? email : 'Adresse non renseignée');
      lines
        ..add('')
        ..add('Votre e-mail est déjà validé.');
      return lines.join('\n');
    }

    lines
      ..add('')
      ..add('3. Vous connecter avec :')
      ..add(email.isNotEmpty ? email : 'Adresse non renseignée')
      ..add('')
      ..add('Important : faites bien les étapes dans cet ordre.');

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
    ];

    lines
      ..add('')
      ..add('1. Ouvrez le lien ci-dessous pour définir votre mot de passe :')
      ..add(passwordSetupLink ??
          'Lien indisponible, contacter l’administration.');

    if (requiresEmailVerification) {
      lines
        ..add('')
        ..add(
          '2. Après avoir défini votre mot de passe, ouvrez ce lien pour valider votre adresse e-mail :',
        )
        ..add(emailVerificationLink!)
        ..add('')
        ..add(
          '3. Une fois ces deux étapes terminées, connectez-vous à l’application avec cette adresse :',
        )
        ..add(email.isNotEmpty ? email : 'Adresse non renseignée')
        ..add('')
        ..add(
          'Important : commencez bien par le mot de passe, puis la validation de l’e-mail.',
        );
    } else {
      lines
        ..add('')
        ..add('2. Ensuite, connectez-vous à l’application avec cette adresse :')
        ..add(email.isNotEmpty ? email : 'Adresse non renseignée')
        ..add('')
        ..add('Aucune validation supplémentaire de l’e-mail n’est nécessaire.');
    }

    lines
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
