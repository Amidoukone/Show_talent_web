import 'package:flutter/material.dart';

import '../theme/admin_theme.dart';
import '../theme/admin_type.dart';

enum AdminVideoActionTone { neutral, info, success, warning, danger }

/// Une vidéo de la file de modération, telle que le lecteur la reçoit.
///
/// Le lecteur travaille sur une file plutôt que sur une vidéo isolée : un
/// opérateur qui doit revenir à la liste entre chaque décision passe son temps
/// à naviguer au lieu de juger.
class AdminVideoQueueEntry {
  const AdminVideoQueueEntry({
    required this.videoUrl,
    required this.userId,
    required this.videoId,
    this.title,
    this.authorName,
    this.metadata = const <AdminVideoMetaItem>[],
    this.decisions = const <AdminVideoDecision>[],
  });

  final String videoUrl;
  final String userId;
  final String videoId;
  final String? title;
  final String? authorName;
  final List<AdminVideoMetaItem> metadata;
  final List<AdminVideoDecision> decisions;

  String get displayTitle {
    final trimmed = title?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      return trimmed;
    }
    return 'Vidéo $videoId';
  }
}

/// Une décision de modération, telle que le lecteur peut la proposer.
///
/// Le lecteur ne sait pas approuver ni refuser une vidéo : il reçoit les
/// décisions de l'écran qui l'ouvre, qui garde sa logique, ses confirmations
/// et ses messages. Sans cela, la même règle métier existerait en deux
/// exemplaires — celui de la liste et celui du lecteur.
class AdminVideoDecision {
  const AdminVideoDecision({
    required this.label,
    required this.icon,
    required this.onInvoke,
    this.tone = AdminVideoActionTone.neutral,
    this.outlined = false,
    this.closesPlayer = true,
  });

  final String label;
  final IconData icon;

  /// Exécute la décision. Rend `true` si elle a bien été appliquée : un refus
  /// dont l'opérateur annule la boîte de motif rend `false`, et le lecteur
  /// reste alors ouvert au lieu de se fermer sur une action qui n'a pas eu
  /// lieu.
  final Future<bool> Function() onInvoke;

  final AdminVideoActionTone tone;
  final bool outlined;

  /// Referme le lecteur quand la décision a été appliquée.
  final bool closesPlayer;
}

class AdminVideoMetaItem {
  const AdminVideoMetaItem({
    required this.label,
    this.icon,
    this.color = AdminTheme.textSecondary,
  });

  final String label;
  final IconData? icon;
  final Color color;
}

/// Vignette d'une vidéo.
///
/// Posée à plat : plus d'ombre portée ni de rayon de 18, et un format
/// 16/9 franc. Les deux tailles correspondent aux deux usages réels —
/// [dense] pour une ligne de tableau, la taille pleine pour une fiche ou
/// une carte en disposition compacte.
class AdminVideoPreviewCard extends StatelessWidget {
  const AdminVideoPreviewCard({
    required this.thumbnailUrl,
    required this.statusColor,
    this.dense = false,
    this.fallbackIcon = Icons.video_library_outlined,
    super.key,
  });

  final String thumbnailUrl;
  final Color statusColor;
  final bool dense;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    final width = dense ? 68.0 : 112.0;
    final height = dense ? 40.0 : 64.0;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AdminTheme.surfaceSunken,
        borderRadius: BorderRadius.circular(AdminTheme.radiusSm),
        border: Border.all(color: AdminTheme.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AdminTheme.radiusSm - 1),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              thumbnailUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Center(
                  child: Icon(
                    fallbackIcon,
                    color: AdminTheme.textMuted,
                    size: dense ? 16 : 22,
                  ),
                );
              },
            ),
            Center(
              child: Container(
                width: dense ? 20 : 28,
                height: dense ? 20 : 28,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.46),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: dense ? 14 : 18,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Cellule « contenu » d'une ligne vidéo : titre, précision, et au plus
/// un marqueur d'alerte.
///
/// Elle empilait jusqu'à quatre pastilles de métadonnées sous deux lignes
/// de texte, ce qui imposait des lignes de 122 px. Les métadonnées
/// complètes vivent désormais dans le lecteur, qui les reçoit déjà.
class AdminVideoTitleCell extends StatelessWidget {
  const AdminVideoTitleCell({
    required this.title,
    required this.subtitle,
    this.alert,
    super.key,
  });

  final String title;
  final String subtitle;

  /// Signalements en attente, visibles sans ouvrir la vidéo.
  final String? alert;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AdminType.bodyStrong,
        ),
        Row(
          children: [
            Flexible(
              child: Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AdminType.caption,
              ),
            ),
            if (alert != null) ...[
              const SizedBox(width: AdminTheme.space2),
              Icon(Icons.flag_outlined, size: 12, color: AdminTheme.warning),
              const SizedBox(width: 3),
              Text(
                alert!,
                style: AdminType.caption.copyWith(
                  color: AdminTheme.warning,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// Bouton d'action du lecteur de modération.
///
/// Aligné sur les boutons du reste du portail : coins arrondis de
/// [AdminTheme.radiusSm], hauteur [AdminTheme.controlHeight], remplissage
/// plein pour la décision principale et contour pour les autres. Le
/// « stadium » et les 40 px d'origine en faisaient des objets à part.
class AdminVideoActionButton extends StatelessWidget {
  const AdminVideoActionButton({
    required this.label,
    required this.icon,
    this.onPressed,
    this.tone = AdminVideoActionTone.neutral,
    this.outlined = false,
    super.key,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final AdminVideoActionTone tone;
  final bool outlined;

  Color get _toneColor {
    switch (tone) {
      case AdminVideoActionTone.info:
        return AdminTheme.cyan;
      case AdminVideoActionTone.success:
        return AdminTheme.success;
      case AdminVideoActionTone.warning:
        return AdminTheme.warning;
      case AdminVideoActionTone.danger:
        return AdminTheme.danger;
      case AdminVideoActionTone.neutral:
        return AdminTheme.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AdminTheme.radiusSm),
    );

    if (outlined) {
      return OutlinedButton.icon(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: _toneColor,
          side: BorderSide(color: _toneColor.withValues(alpha: 0.42)),
          padding: const EdgeInsets.symmetric(horizontal: AdminTheme.space3),
          shape: shape,
          minimumSize: const Size(0, AdminTheme.controlHeight),
        ),
        icon: Icon(icon, size: 16),
        label: Text(label),
      );
    }

    return FilledButton.tonalIcon(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: _toneColor.withValues(alpha: 0.16),
        foregroundColor: _toneColor,
        padding: const EdgeInsets.symmetric(horizontal: AdminTheme.space3),
        shape: shape,
        minimumSize: const Size(0, AdminTheme.controlHeight),
      ),
      icon: Icon(icon, size: 16),
      label: Text(label),
    );
  }
}
