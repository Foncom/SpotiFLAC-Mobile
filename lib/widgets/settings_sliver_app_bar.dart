import 'package:flutter/material.dart';
import 'package:spotiflac_android/utils/app_bar_layout.dart';

/// The collapsing header shared by settings-style pages: a pinned
/// [SliverAppBar] whose title slides toward the leading edge and shrinks
/// from 28 to 20 logical pixels as the header collapses.
class SettingsSliverAppBar extends StatelessWidget {
  const SettingsSliverAppBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
  });

  final String title;
  final List<Widget>? actions;

  /// Defaults to a back button popping the current route.
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final topPadding = normalizedHeaderTopPadding(context);
    return SliverAppBar(
      expandedHeight: 120 + topPadding,
      collapsedHeight: kToolbarHeight,
      floating: false,
      pinned: true,
      backgroundColor: colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      leading: leading ??
          IconButton(
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
      actions: actions,
      flexibleSpace: LayoutBuilder(
        builder: (context, constraints) {
          final maxHeight = 120 + topPadding;
          final minHeight = kToolbarHeight + topPadding;
          final expandRatio =
              ((constraints.maxHeight - minHeight) / (maxHeight - minHeight))
                  .clamp(0.0, 1.0);
          final leftPadding = 56 - (32 * expandRatio);
          return FlexibleSpaceBar(
            expandedTitleScale: 1.0,
            titlePadding: EdgeInsets.only(left: leftPadding, bottom: 16),
            title: Text(
              title,
              style: TextStyle(
                fontSize: 20 + (8 * expandRatio),
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
          );
        },
      ),
    );
  }
}
