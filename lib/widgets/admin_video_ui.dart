import 'package:flutter/material.dart';

import '../theme/admin_theme.dart';

enum AdminVideoActionTone { neutral, info, success, warning, danger }

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

class AdminVideoPreviewCard extends StatelessWidget {
  const AdminVideoPreviewCard({
    required this.thumbnailUrl,
    required this.statusLabel,
    required this.statusColor,
    required this.footerLabel,
    this.compact = false,
    this.footerIcon,
    this.fallbackIcon = Icons.video_library_outlined,
    super.key,
  });

  final String thumbnailUrl;
  final String statusLabel;
  final Color statusColor;
  final String footerLabel;
  final bool compact;
  final IconData? footerIcon;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    final width = compact ? 122.0 : 142.0;
    final height = compact ? 74.0 : 84.0;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: statusColor.withValues(alpha: 0.24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(color: AdminTheme.surfaceSoft),
            Image.network(
              thumbnailUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Center(
                  child: Icon(
                    fallbackIcon,
                    color: statusColor,
                    size: compact ? 28 : 32,
                  ),
                );
              },
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.06),
                    Colors.black.withValues(alpha: 0.22),
                    Colors.black.withValues(alpha: 0.58),
                  ],
                  stops: const [0.0, 0.48, 1.0],
                ),
              ),
            ),
            Positioned(
              left: 8,
              right: 8,
              top: 8,
              child: Align(
                alignment: Alignment.topRight,
                child: _AdminVideoOverlayChip(
                  label: statusLabel,
                  color: statusColor,
                  compact: compact,
                ),
              ),
            ),
            Positioned(
              left: 8,
              bottom: 8,
              child: _AdminVideoOverlayChip(
                label: footerLabel,
                color: Colors.white,
                icon: footerIcon,
                compact: compact,
              ),
            ),
            Center(
              child: Container(
                width: compact ? 34 : 38,
                height: compact ? 34 : 38,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.38),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AdminVideoTitleCell extends StatelessWidget {
  const AdminVideoTitleCell({
    required this.title,
    required this.subtitle,
    this.metadata = const <AdminVideoMetaItem>[],
    this.maxWidth = 320,
    super.key,
  });

  final String title;
  final String subtitle;
  final List<AdminVideoMetaItem> metadata;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AdminTheme.textPrimary,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AdminTheme.textSecondary,
              fontSize: 12,
              height: 1.35,
            ),
          ),
          if (metadata.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: metadata
                  .map(
                    (item) => _AdminVideoMetaChip(
                      label: item.label,
                      icon: item.icon,
                      color: item.color,
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

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
        return AdminTheme.accentSoft;
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = outlined
        ? OutlinedButton.styleFrom(
            foregroundColor: _toneColor,
            side: BorderSide(color: _toneColor.withValues(alpha: 0.36)),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            shape: const StadiumBorder(),
            minimumSize: const Size(0, 40),
            visualDensity: VisualDensity.compact,
          )
        : FilledButton.styleFrom(
            backgroundColor: _toneColor.withValues(alpha: 0.14),
            foregroundColor: _toneColor,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            shape: const StadiumBorder(),
            minimumSize: const Size(0, 40),
            visualDensity: VisualDensity.compact,
          );

    if (outlined) {
      return OutlinedButton.icon(
        onPressed: onPressed,
        style: style,
        icon: Icon(icon, size: 18),
        label: Text(label),
      );
    }

    return FilledButton.tonalIcon(
      onPressed: onPressed,
      style: style,
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}

class _AdminVideoMetaChip extends StatelessWidget {
  const _AdminVideoMetaChip({
    required this.label,
    required this.color,
    this.icon,
  });

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminVideoOverlayChip extends StatelessWidget {
  const _AdminVideoOverlayChip({
    required this.label,
    required this.color,
    this.compact = false,
    this.icon,
  });

  final String label;
  final Color color;
  final bool compact;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 5,
      ),
      decoration: BoxDecoration(
        color: color == Colors.white
            ? Colors.black.withValues(alpha: 0.34)
            : color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: color == Colors.white
              ? Colors.white.withValues(alpha: 0.18)
              : color.withValues(alpha: 0.28),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: compact ? 11 : 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: compact ? 10 : 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
