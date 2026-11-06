import 'dart:async';

import 'package:flutter/material.dart';

/// Boîte de dialogue de compte à rebours avant la déconnexion automatique.
///
/// Son propre minuteur, pas celui du service appelant : une fois affichée,
/// la seule façon d'avancer est son bouton ou l'écoulement du délai — le
/// service n'a besoin de savoir que lequel des deux s'est produit.
class InactivityWarningDialog extends StatefulWidget {
  const InactivityWarningDialog({required this.duration, super.key});

  final Duration duration;

  @override
  State<InactivityWarningDialog> createState() =>
      _InactivityWarningDialogState();
}

class _InactivityWarningDialogState extends State<InactivityWarningDialog> {
  late int _secondsRemaining;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _secondsRemaining = widget.duration.inSeconds;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_secondsRemaining <= 1) {
        _ticker?.cancel();
        Navigator.of(context).pop(false);
        return;
      }
      setState(() => _secondsRemaining -= 1);
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Inactivité détectée'),
      content: Text(
        'Par mesure de sécurité, vous serez déconnecté dans '
        '$_secondsRemaining secondes sans action de votre part.',
      ),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Rester connecté'),
        ),
      ],
    );
  }
}
