/// La logique de lecture du lecteur de modération, sans dépendance au plugin
/// vidéo pour qu'elle reste vérifiable en test.
///
/// Le lecteur d'un portail de modération n'a pas le même métier qu'un lecteur
/// de divertissement : on y revient en arrière de quelques secondes, on
/// ralentit une action pour la juger, on repasse le même passage. Ce sont ces
/// règles-là qui vivent ici.
library;

/// Les vitesses proposées, de la plus lente à la plus rapide.
///
/// 0,25x et 0,5x servent à juger un geste technique ; 1,5x et 2x à traverser
/// une vidéo longue sans y passer la journée.
const List<double> videoModerationSpeeds = <double>[0.25, 0.5, 1.0, 1.5, 2.0];

/// Le saut « large », pour retrouver un passage.
const Duration videoModerationCoarseStep = Duration(seconds: 10);

/// Le saut « fin », pour se caler sur une action.
const Duration videoModerationFineStep = Duration(seconds: 1);

/// Le saut du clavier avec les flèches.
const Duration videoModerationArrowStep = Duration(seconds: 5);

/// Ramène une position demandée dans les bornes de la vidéo.
///
/// Reculer avant le début ou avancer après la fin ne sont pas des erreurs :
/// c'est ce que produit un appui répété sur « -10 s » près du début, et le
/// lecteur doit y répondre par le début de la vidéo, pas par un refus.
Duration clampSeekTarget({required Duration target, required Duration total}) {
  if (total <= Duration.zero) {
    return Duration.zero;
  }
  if (target < Duration.zero) {
    return Duration.zero;
  }
  if (target > total) {
    return total;
  }
  return target;
}

/// La position après un saut de [step] depuis [position].
Duration seekBy({
  required Duration position,
  required Duration step,
  required Duration total,
}) {
  return clampSeekTarget(target: position + step, total: total);
}

/// Formate une position pour l'affichage : `m:ss`, ou `h:mm:ss` au-delà d'une
/// heure — une vidéo de trois minutes n'a pas à afficher un `0:` inutile.
String formatPlaybackTimestamp(Duration position) {
  final safe = position < Duration.zero ? Duration.zero : position;
  final hours = safe.inHours;
  final minutes = safe.inMinutes.remainder(60);
  final seconds = safe.inSeconds.remainder(60);
  final paddedSeconds = seconds.toString().padLeft(2, '0');

  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}:$paddedSeconds';
  }
  return '$minutes:$paddedSeconds';
}

/// Formate une vitesse : `1x`, `0,5x`.
///
/// Virgule décimale : le portail est en français, et `0.5x` au milieu d'une
/// interface francophone se lit comme une coquille.
String formatPlaybackSpeed(double speed) {
  if (speed == speed.roundToDouble()) {
    return '${speed.round()}x';
  }
  return '${speed.toString().replaceAll('.', ',')}x';
}

/// La vitesse suivante dans le cycle, pour un raccourci qui ne veut pas ouvrir
/// de menu. Revient à la première après la dernière.
double nextPlaybackSpeed(double current) {
  final index = videoModerationSpeeds.indexOf(current);
  if (index == -1) {
    return 1.0;
  }
  return videoModerationSpeeds[(index + 1) % videoModerationSpeeds.length];
}

/// La progression dans la vidéo, entre 0 et 1.
///
/// Zéro tant que la durée est inconnue : au chargement, `position / 0` vaut
/// NaN, et une barre de progression pilotée par NaN lève une assertion.
double playbackProgress({required Duration position, required Duration total}) {
  if (total <= Duration.zero) {
    return 0;
  }
  final ratio = position.inMilliseconds / total.inMilliseconds;
  if (ratio.isNaN) {
    return 0;
  }
  return ratio.clamp(0.0, 1.0);
}
