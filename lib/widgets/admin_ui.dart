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
    this.radius = 18,
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

class AdminContentFrame extends StatelessWidget {
  const AdminContentFrame({
    required this.child,
    this.maxWidth = AdminTheme.readingMaxWidth,
    super.key,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

class AdminBrandMark extends StatelessWidget {
  const AdminBrandMark({
    this.size = 54,
    this.width,
    this.label = 'AD',
    super.key,
  });

  final double size;
  final double? width;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width ?? size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AdminTheme.accent,
            AdminTheme.cyan,
          ],
        ),
        borderRadius: BorderRadius.circular(size * 0.28),
        border: Border.all(
          color: AdminTheme.accentSoft.withValues(alpha: 0.34),
        ),
      ),
      child: Center(
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: AdminTheme.background,
            fontSize: label.length > 2 ? size * 0.22 : size * 0.32,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
      ),
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
        final compactTitle = constraints.maxWidth < 560;
        final titleStyle = compactTitle
            ? textTheme.headlineMedium?.copyWith(
                fontSize: 24,
                height: 1.15,
              )
            : textTheme.headlineMedium;

        final titleBlock = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (badge != null) ...[
              AdminPill(
                label: badge!,
                icon: Icons.auto_awesome,
                color: AdminTheme.accentSoft,
              ),
              const SizedBox(height: 12),
            ],
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: trailing == null ? 760 : 680,
              ),
              child: Text(
                title,
                style: titleStyle,
                maxLines: compactTitle ? 3 : 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: trailing == null ? 760 : 680,
                ),
                child: Text(
                  subtitle!,
                  style: textTheme.bodyMedium,
                  maxLines: vertical ? 4 : 2,
                  overflow: TextOverflow.ellipsis,
                ),
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
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: titleBlock),
            if (trailing != null) ...[
              const SizedBox(width: 16),
              trailing!,
            ],
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
    final compact = MediaQuery.sizeOf(context).width < 640;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 16 : 18),
      decoration: BoxDecoration(
        color: _toneColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _toneColor.withValues(alpha: 0.18)),
      ),
      child: Flex(
        direction: compact ? Axis.vertical : Axis.horizontal,
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
          SizedBox(width: compact ? 0 : 14, height: compact ? 12 : 0),
          Expanded(
            flex: compact ? 0 : 1,
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

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 156),
      child: AdminGlassPanel(
        highlight: true,
        accentColor: accentColor,
        padding: const EdgeInsets.all(18),
        radius: 18,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 18, color: accentColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 34,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AdminTheme.textSecondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                _AdminRing(
                  color: accentColor,
                  progress: progress,
                  label: '$percent%',
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              value,
              style: const TextStyle(
                fontSize: 29,
                fontWeight: FontWeight.w800,
                color: AdminTheme.textPrimary,
                letterSpacing: 0,
                height: 1,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              SizedBox(
                height: 32,
                child: Text(
                  subtitle!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AdminTheme.textMuted,
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ],
        ),
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
        padding: const EdgeInsets.all(14),
        radius: 16,
        accentColor: accentColor,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: accentColor.withValues(alpha: 0.22),
                ),
              ),
              child: Icon(icon, color: accentColor, size: 19),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 32,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AdminTheme.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
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
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AdminTheme.textMuted,
                        fontSize: 11,
                        height: 1.3,
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
      padding: const EdgeInsets.all(18),
      radius: 18,
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
            const SizedBox(height: 6),
            Text(
              subtitle!,
              style: const TextStyle(
                color: AdminTheme.textSecondary,
                height: 1.45,
              ),
            ),
          ],
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class AdminFormColumn extends StatelessWidget {
  const AdminFormColumn({
    required this.children,
    this.maxWidth = 520,
    this.spacing = 16,
    this.crossAxisAlignment = CrossAxisAlignment.stretch,
    super.key,
  });

  final List<Widget> children;
  final double maxWidth;
  final double spacing;
  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) {
    final spacedChildren = <Widget>[];
    for (var index = 0; index < children.length; index += 1) {
      if (index > 0) {
        spacedChildren.add(SizedBox(height: spacing));
      }
      spacedChildren.add(children[index]);
    }

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: crossAxisAlignment,
          children: spacedChildren,
        ),
      ),
    );
  }
}

class AdminSearchField extends StatelessWidget {
  const AdminSearchField({
    required this.hintText,
    this.onChanged,
    this.controller,
    this.maxWidth,
    super.key,
  });

  final String hintText;
  final ValueChanged<String>? onChanged;
  final TextEditingController? controller;
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    final field = TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: const Icon(Icons.search_rounded),
      ),
    );

    if (maxWidth == null) {
      return field;
    }

    return Align(
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth!),
        child: field,
      ),
    );
  }
}

class AdminFilterBar extends StatelessWidget {
  const AdminFilterBar({
    required this.children,
    this.flexes,
    this.maxWidth = 860,
    this.spacing = 10,
    this.breakpoint = 760,
    super.key,
  });

  final List<Widget> children;
  final List<int>? flexes;
  final double maxWidth;
  final double spacing;
  final double breakpoint;

  @override
  Widget build(BuildContext context) {
    assert(
      flexes == null || flexes!.length == children.length,
      'flexes must match children length.',
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < breakpoint;

        if (stacked) {
          return AdminFormColumn(
            maxWidth: maxWidth,
            spacing: spacing,
            children: children,
          );
        }

        final rowChildren = <Widget>[];
        for (var index = 0; index < children.length; index += 1) {
          if (index > 0) {
            rowChildren.add(SizedBox(width: spacing));
          }
          rowChildren.add(
            Expanded(
              flex: flexes?[index] ?? 1,
              child: children[index],
            ),
          );
        }

        return Align(
          alignment: Alignment.center,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Row(children: rowChildren),
          ),
        );
      },
    );
  }
}

class AdminLoadingState extends StatelessWidget {
  const AdminLoadingState({
    this.message = 'Chargement des donn\u00e9es...',
    super.key,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return AdminGlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AdminTheme.accent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
          ),
          const SizedBox(width: 14),
          Flexible(
            child: Text(
              message,
              style: const TextStyle(
                color: AdminTheme.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
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
      radius: compact ? 16 : 18,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(compact ? 16 : 18),
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
                padding: EdgeInsets.all(compact ? 6 : 8),
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
    this.previousLabel = 'Pr\u00e9c\u00e9dent',
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
      width: 52,
      height: 52,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 52,
            height: 52,
            child: CircularProgressIndicator(
              value: progress.clamp(0, 1),
              strokeWidth: 4.5,
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
