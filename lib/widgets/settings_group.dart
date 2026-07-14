import 'package:flutter/material.dart';
import 'package:spotiflac_android/utils/adaptive_layout.dart';

/// Background fill for grouped cards, matching the Settings group look. Blends a
/// translucent overlay over the surface so it stays visible on AMOLED (pure
/// black) dark themes as well as normal light/dark themes.
Color settingsGroupColor(BuildContext context) {
  final colorScheme = Theme.of(context).colorScheme;
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return isDark
      ? Color.alphaBlend(
          Colors.white.withValues(alpha: 0.08),
          colorScheme.surface,
        )
      : Color.alphaBlend(
          Colors.black.withValues(alpha: 0.04),
          colorScheme.surface,
        );
}

class SettingsGroup extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsetsGeometry? margin;

  const SettingsGroup({super.key, required this.children, this.margin});

  @override
  Widget build(BuildContext context) {
    final cardColor = settingsGroupColor(context);
    final colorScheme = Theme.of(context).colorScheme;

    final decoration = BoxDecoration(
      color: cardColor,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: colorScheme.outlineVariant.withValues(alpha: 0.5),
      ),
    );
    final child = Material(
      color: Colors.transparent,
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    );

    // Explicit caller margin wins as-is. Otherwise center on wide surfaces
    // using the incoming constraint (not screen width) so groups nested in an
    // already clamped box, e.g. a bottom sheet, are not over-inset.
    if (margin != null) {
      return Container(
        margin: margin,
        decoration: decoration,
        clipBehavior: Clip.antiAlias,
        child: child,
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) => Container(
        margin: EdgeInsets.symmetric(
          horizontal:
              16 +
              (constraints.hasBoundedWidth
                  ? wideInsetForWidth(constraints.maxWidth)
                  : 0),
          vertical: 4,
        ),
        decoration: decoration,
        clipBehavior: Clip.antiAlias,
        child: child,
      ),
    );
  }
}

class SettingsItem extends StatelessWidget {
  final IconData? icon;
  final String title;
  final Widget? titleTrailing;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showDivider;

  const SettingsItem({
    super.key,
    this.icon,
    required this.title,
    this.titleTrailing,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onTap,
          splashColor: colorScheme.primary.withValues(alpha: 0.12),
          highlightColor: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, color: colorScheme.onSurfaceVariant, size: 24),
                  const SizedBox(width: 16),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                          ),
                          if (titleTrailing != null) ...[
                            const SizedBox(width: 8),
                            titleTrailing!,
                          ],
                        ],
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 8),
                  trailing!,
                ] else if (onTap != null) ...[
                  const SizedBox(width: 8),
                  Icon(
                    Icons.chevron_right,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ],
              ],
            ),
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            thickness: 1,
            indent: icon != null ? 56 : 20,
            endIndent: 20,
            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
      ],
    );
  }
}

class SettingsSwitchItem extends StatelessWidget {
  final IconData? icon;
  final String title;
  final Widget? titleTrailing;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool showDivider;
  final bool enabled;

  const SettingsSwitchItem({
    super.key,
    this.icon,
    required this.title,
    this.titleTrailing,
    this.subtitle,
    required this.value,
    this.onChanged,
    this.showDivider = true,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDisabled = !enabled || onChanged == null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Opacity(
          opacity: isDisabled ? 0.5 : 1.0,
          child: InkWell(
            onTap: isDisabled ? null : () => onChanged!(!value),
            splashColor: colorScheme.primary.withValues(alpha: 0.12),
            highlightColor: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  if (icon != null) ...[
                    Icon(
                      icon,
                      color: isDisabled
                          ? colorScheme.outline
                          : colorScheme.onSurfaceVariant,
                      size: 24,
                    ),
                    const SizedBox(width: 16),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                title,
                                style: Theme.of(context).textTheme.bodyLarge
                                    ?.copyWith(
                                      color: isDisabled
                                          ? colorScheme.outline
                                          : null,
                                    ),
                              ),
                            ),
                            if (titleTrailing != null) ...[
                              const SizedBox(width: 8),
                              titleTrailing!,
                            ],
                          ],
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle!,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: isDisabled
                                      ? colorScheme.outline
                                      : colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Switch(
                    value: value,
                    onChanged: isDisabled ? null : onChanged,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            thickness: 1,
            indent: icon != null ? 56 : 20,
            endIndent: 20,
            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
      ],
    );
  }
}

class SettingsSectionHeader extends StatelessWidget {
  final String title;

  const SettingsSectionHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Small "BETA" pill, used as a [SettingsItem.titleTrailing] /
/// [SettingsSwitchItem.titleTrailing] marker for experimental features.
class BetaBadge extends StatelessWidget {
  final String label;

  const BetaBadge({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: colorScheme.onTertiaryContainer,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
