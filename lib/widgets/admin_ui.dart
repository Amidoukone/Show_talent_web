import 'package:flutter/material.dart';

import '../theme/admin_theme.dart';

enum AdminBannerTone { neutral, success, warning, danger, info }

class AdminAppBackground extends StatelessWidget {
  const AdminAppBackground({
    required this.child,
    this.padding = EdgeInsets.zero,
    super.key,
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AdminTheme.pageGradient),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _AdminGridPainter(),
            ),
          ),
          const Positioned(
            top: -180,
            right: -120,
            child: _AmbientGlow(
              size: 320,
              color: AdminTheme.accent,
              opacity: 0.12,
            ),
          ),
          const Positioned(
            bottom: -160,
            left: -80,
            child: _AmbientGlow(
              size: 260,
              color: AdminTheme.cyan,
              opacity: 0.1,
            ),
          ),
          const Positioned(
            top: 140,
            left: 70,
            child: _AmbientGlow(
              size: 180,
              color: AdminTheme.accentSoft,
              opacity: 0.05,
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(
                  color: AdminTheme.borderSoft.withValues(alpha: 0.18),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: padding,
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

class AdminGlassPanel extends StatelessWidget {
  const AdminGlassPanel({
    required this.child,
    this.padding = const EdgeInsets.all(24),
    this.margin,
    this.highlight = false,
    this.accentColor,
    this.radius = 30,
    this.width,
    this.height,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final bool highlight;
  final Color? accentColor;
  final double radius;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      margin: margin,
      padding: padding,
      decoration: AdminTheme.panelDecoration(
        accentColor: accentColor,
        highlight: highlight,
        radius: radius,
      ),
      child: child,
    );
  }
}

class AdminSectionHeader extends StatelessWidget {
  const AdminSectionHeader({
    required this.title,
    this.subtitle,
    this.trailing,
    this.badge,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final vertical = constraints.maxWidth < 760;

        final titleBlock = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (badge != null) ...[
              AdminPill(
                label: badge!,
                icon: Icons.auto_awesome,
                color: AdminTheme.accentSoft,
              ),
              const SizedBox(height: 14),
            ],
            Text(title, style: textTheme.headlineMedium),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                style: textTheme.bodyMedium,
              ),
            ],
          ],
        );

        if (vertical) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              titleBlock,
              if (trailing != null) ...[
                const SizedBox(height: 18),
                trailing!,
              ],
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: titleBlock),
            if (trailing != null) trailing!,
          ],
        );
      },
    );
  }
}

class AdminPill extends StatelessWidget {
  const AdminPill({
    required this.label,
    this.icon,
    this.color = AdminTheme.accent,
    super.key,
  });

  final String label;
  final IconData? icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 8),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class AdminInfoBanner extends StatelessWidget {
  const AdminInfoBanner({
    required this.title,
    required this.message,
    required this.icon,
    this.tone = AdminBannerTone.neutral,
    super.key,
  });

  final String title;
  final String message;
  final IconData icon;
  final AdminBannerTone tone;

  Color get _toneColor {
    switch (tone) {
      case AdminBannerTone.success:
        return AdminTheme.success;
      case AdminBannerTone.warning:
        return AdminTheme.warning;
      case AdminBannerTone.danger:
        return AdminTheme.danger;
      case AdminBannerTone.info:
        return AdminTheme.cyan;
      case AdminBannerTone.neutral:
        return AdminTheme.accent;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _toneColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _toneColor.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _toneColor.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: _toneColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AdminTheme.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  style: const TextStyle(
                    color: AdminTheme.textSecondary,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AdminMetricCard extends StatelessWidget {
  const AdminMetricCard({
    required this.title,
    required this.value,
    required this.icon,
    this.subtitle,
    this.accentColor = AdminTheme.accent,
    this.progress = 0.0,
    super.key,
  });

  final String title;
  final String value;
  final IconData icon;
  final String? subtitle;
  final Color accentColor;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final percent = (progress.clamp(0, 1) * 100).round();

    return AdminGlassPanel(
      highlight: true,
      accentColor: accentColor,
      padding: const EdgeInsets.all(20),
      radius: 26,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 18, color: accentColor),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: AdminTheme.textSecondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: AdminTheme.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      color: AdminTheme.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 14),
          _AdminRing(
            color: accentColor,
            progress: progress,
            label: '$percent%',
          ),
        ],
      ),
    );
  }
}

class AdminMiniStat extends StatelessWidget {
  const AdminMiniStat({
    required this.label,
    required this.value,
    required this.icon,
    this.accentColor = AdminTheme.accent,
    this.subtitle,
    this.minWidth = 220,
    super.key,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color accentColor;
  final String? subtitle;
  final double minWidth;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(minWidth: minWidth, maxWidth: 280),
      child: AdminGlassPanel(
        padding: const EdgeInsets.all(16),
        radius: 22,
        accentColor: accentColor,
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: accentColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: AdminTheme.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      color: AdminTheme.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        color: AdminTheme.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AdminSubsectionCard extends StatelessWidget {
  const AdminSubsectionCard({
    required this.title,
    required this.child,
    this.subtitle,
    this.accentColor = AdminTheme.accent,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return AdminGlassPanel(
      padding: const EdgeInsets.all(20),
      radius: 24,
      accentColor: accentColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: accentColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AdminTheme.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle!,
              style: const TextStyle(
                color: AdminTheme.textSecondary,
                height: 1.45,
              ),
            ),
          ],
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class AdminSearchField extends StatelessWidget {
  const AdminSearchField({
    required this.hintText,
    this.onChanged,
    this.controller,
    super.key,
  });

  final String hintText;
  final ValueChanged<String>? onChanged;
  final TextEditingController? controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: Container(
          margin: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AdminTheme.surfaceHighlight.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.tune_rounded, size: 18),
        ),
      ),
    );
  }
}

class AdminEmptyState extends StatelessWidget {
  const AdminEmptyState({
    required this.title,
    required this.message,
    this.icon = Icons.inbox_rounded,
    this.actionLabel,
    this.actionIcon = Icons.refresh_rounded,
    this.onAction,
    super.key,
  });

  final String title;
  final String message;
  final IconData icon;
  final String? actionLabel;
  final IconData actionIcon;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return AdminGlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 34),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: AdminTheme.accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AdminTheme.accent, size: 30),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AdminTheme.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(
              color: AdminTheme.textSecondary,
              height: 1.45,
            ),
            textAlign: TextAlign.center,
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onAction,
              icon: Icon(actionIcon, size: 18),
              label: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

class AdminDataTableCard extends StatelessWidget {
  const AdminDataTableCard({
    required this.child,
    this.compact = false,
    super.key,
  });

  final Widget child;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return AdminGlassPanel(
      padding: EdgeInsets.zero,
      radius: compact ? 20 : 26,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(compact ? 20 : 26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 2,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    AdminTheme.accent.withValues(alpha: 0.7),
                    AdminTheme.cyan.withValues(alpha: 0.7),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Padding(
                padding: EdgeInsets.all(compact ? 8 : 10),
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AdminPaginationBar extends StatelessWidget {
  const AdminPaginationBar({
    required this.currentPage,
    required this.totalPages,
    required this.onPrevious,
    required this.onNext,
    this.previousLabel = 'Précédent',
    this.nextLabel = 'Suivant',
    super.key,
  });

  final int currentPage;
  final int totalPages;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final String previousLabel;
  final String nextLabel;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final vertical = constraints.maxWidth < 720;

        final buttons = Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            OutlinedButton.icon(
              onPressed: onPrevious,
              icon: const Icon(Icons.arrow_back_rounded),
              label: Text(previousLabel),
            ),
            ElevatedButton.icon(
              onPressed: onNext,
              icon: const Icon(Icons.arrow_forward_rounded),
              label: Text(nextLabel),
            ),
          ],
        );

        final label = Text(
          'Page ${currentPage + 1} sur ${totalPages == 0 ? 1 : totalPages}',
          style: const TextStyle(
            color: AdminTheme.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        );

        if (vertical) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              label,
              const SizedBox(height: 14),
              buttons,
            ],
          );
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            label,
            buttons,
          ],
        );
      },
    );
  }
}

class _AmbientGlow extends StatelessWidget {
  const _AmbientGlow({
    required this.size,
    required this.color,
    required this.opacity,
  });

  final double size;
  final Color color;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: opacity),
              blurRadius: size * 0.45,
              spreadRadius: size * 0.12,
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = AdminTheme.borderSoft.withValues(alpha: 0.16)
      ..strokeWidth = 1;
    const gap = 140.0;

    for (double x = 0; x <= size.width; x += gap) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
    }

    for (double y = 0; y <= size.height; y += gap) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    final accentPaint = Paint()
      ..shader = const LinearGradient(
        colors: [
          Color(0x00000000),
          AdminTheme.accent,
          Color(0x00000000),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, 2))
      ..strokeWidth = 1.2;

    canvas.drawLine(
      Offset(size.width * 0.08, 28),
      Offset(size.width * 0.92, 28),
      accentPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _AdminRing extends StatelessWidget {
  const _AdminRing({
    required this.color,
    required this.progress,
    required this.label,
  });

  final Color color;
  final double progress;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 60,
      height: 60,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 60,
            height: 60,
            child: CircularProgressIndicator(
              value: progress.clamp(0, 1),
              strokeWidth: 6,
              backgroundColor: AdminTheme.borderSoft,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
