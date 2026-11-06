import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/inactivity_service.dart';

/// Pose la détection globale d'activité (pointeur + clavier) au-dessus de
/// l'application entière.
///
/// Doit envelopper le résultat du `builder` de `MaterialApp`, pas un seul
/// écran : un `Listener` posé seulement autour du tableau de bord ne verrait
/// jamais les clics dans une boîte de dialogue (`showDialog`/`Get.dialog`),
/// rendue par l'`Overlay` racine, donc hors de l'arbre de cet écran.
/// Le clavier est capté par [HardwareKeyboard], indépendant du focus : taper
/// dans un champ de recherche compte comme une activité même sans mouvement
/// de souris.
class InactivityGuard extends StatefulWidget {
  const InactivityGuard({required this.child, super.key});

  final Widget child;

  @override
  State<InactivityGuard> createState() => _InactivityGuardState();
}

class _InactivityGuardState extends State<InactivityGuard> {
  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    super.dispose();
  }

  bool _handleKeyEvent(KeyEvent event) {
    InactivityService.instance.registerActivity();
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => InactivityService.instance.registerActivity(),
      onPointerSignal: (_) => InactivityService.instance.registerActivity(),
      child: widget.child,
    );
  }
}
