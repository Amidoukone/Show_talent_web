import 'dart:async';

import 'package:get/get.dart';

import '../widgets/inactivity_warning_dialog.dart';

/// Déconnexion automatique après inactivité, avec avertissement.
///
/// Singleton plutôt qu'un widget d'écran : l'activité à surveiller (clic,
/// frappe) se produit n'importe où dans l'app, y compris dans une boîte de
/// dialogue rendue par l'Overlay — pas seulement dans l'arbre d'un écran
/// particulier. [InactivityGuard] (lib/widgets/inactivity_guard.dart) pose
/// la détection globale et relaie ici ; [registerActivity] ne fait rien tant
/// que [start] n'a pas été appelé (hors session authentifiée).
///
/// [onTimeout] est injecté par l'appelant plutôt que câblé en dur sur
/// AuthController/AppRoutes : ce service n'a besoin de savoir que "quoi
/// faire à l'expiration", pas comment une session s'y connecte — exactement
/// le même principe que AdminContentService/ManagedAccountService.
class InactivityService {
  InactivityService._();

  static final InactivityService instance = InactivityService._();

  static const Duration idleTimeout = Duration(minutes: 15);
  static const Duration warningLeadTime = Duration(seconds: 60);

  bool _running = false;
  bool _warningShowing = false;
  Timer? _preWarningTimer;
  Future<void> Function()? _onTimeout;

  void start({required Future<void> Function() onTimeout}) {
    _running = true;
    _onTimeout = onTimeout;
    _armPreWarningTimer();
  }

  void stop() {
    _running = false;
    _warningShowing = false;
    _onTimeout = null;
    _preWarningTimer?.cancel();
    _preWarningTimer = null;
  }

  void registerActivity() {
    if (!_running || _warningShowing) {
      return;
    }
    _armPreWarningTimer();
  }

  void _armPreWarningTimer() {
    _preWarningTimer?.cancel();
    _preWarningTimer = Timer(idleTimeout - warningLeadTime, _showWarning);
  }

  Future<void> _showWarning() async {
    if (!_running) {
      return;
    }

    _warningShowing = true;
    final staySignedIn = await Get.dialog<bool>(
      const InactivityWarningDialog(duration: warningLeadTime),
      barrierDismissible: false,
    );
    _warningShowing = false;

    if (!_running) {
      return;
    }

    if (staySignedIn == true) {
      _armPreWarningTimer();
    } else {
      final onTimeout = _onTimeout;
      stop();
      await onTimeout?.call();
    }
  }
}
