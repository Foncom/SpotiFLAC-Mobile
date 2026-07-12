import 'dart:ui';

import 'package:flutter/material.dart';

/// Collapsing album-detail header shared by the album, local-album, and
/// downloaded-album screens: full-bleed [background] (optionally blurred and
/// scrimmed), bottom gradient, centered square cover, title, optional
/// subtitle/meta/actions rows, and a circular back button. Content fades out
/// below 30% expansion; the [title] fades into the toolbar instead.
class AlbumDetailHeader extends StatelessWidget {
  const AlbumDetailHeader({
    super.key,
    required this.title,
    required this.expandedHeight,
    required this.showTitleInAppBar,
    required this.background,
    this.blurAndScrimBackground = true,
    this.coverBuilder,
    this.subtitle,
    this.meta,
    this.actions,
    this.appBarActions,
    this.appBarTitle,
    this.leading,
    this.backgroundColor,
  });

  final String title;
  final double expandedHeight;
  final bool showTitleInAppBar;

  /// Full-bleed background content (cover image, motion banner, placeholder).
  final Widget background;

  /// Blur the background and dim it 35%; disable for motion banners and
  /// placeholder backgrounds.
  final bool blurAndScrimBackground;

  /// Builds the centered square cover for the given side length; null hides
  /// the cover block (the header wraps it in the shared shadow + rounding).
  final Widget Function(BuildContext context, double coverSize)? coverBuilder;

  /// Artist line under the title (plain text or a clickable artist widget).
  final Widget? subtitle;

  /// "•"-joined meta row under the subtitle.
  final Widget? meta;

  /// Action row (play/shuffle, download-all, ...) under the meta row.
  final Widget? actions;

  /// Extra toolbar actions (top-right).
  final List<Widget>? appBarActions;

  /// Toolbar title when it should differ from [title] (e.g. a selection
  /// count); defaults to [title].
  final String? appBarTitle;

  /// Replaces the default circular back button.
  final Widget? leading;

  final Color? backgroundColor;

  /// Shrinks long titles so up to three lines fit the header.
  double _titleFontSize() {
    final length = title.trim().length;
    if (length > 45) return 18;
    if (length > 30) return 21;
    return 24;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SliverAppBar(
      expandedHeight: expandedHeight,
      pinned: true,
      stretch: true,
      backgroundColor: backgroundColor ?? colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      title: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: showTitleInAppBar ? 1.0 : 0.0,
        child: Text(
          appBarTitle ?? title,
          style: TextStyle(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      flexibleSpace: LayoutBuilder(
        builder: (context, constraints) {
          final collapseRatio =
              (constraints.maxHeight - kToolbarHeight) /
              (expandedHeight - kToolbarHeight);
          final showContent = collapseRatio > 0.3;

          return FlexibleSpaceBar(
            collapseMode: CollapseMode.pin,
            background: Stack(
              fit: StackFit.expand,
              children: [
                if (blurAndScrimBackground)
                  ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: 32, sigmaY: 32),
                    child: background,
                  )
                else
                  background,
                if (blurAndScrimBackground)
                  Container(color: Colors.black.withValues(alpha: 0.35)),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: expandedHeight * 0.65,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.85),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: 40,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 150),
                    opacity: showContent ? 1.0 : 0.0,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (coverBuilder != null) ...[
                          Builder(
                            builder: (context) {
                              final coverSize = (constraints.maxWidth * 0.5)
                                  .clamp(150.0, 210.0)
                                  .toDouble();
                              return Container(
                                width: coverSize,
                                height: coverSize,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.45,
                                      ),
                                      blurRadius: 24,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: coverBuilder!(context, coverSize),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 20),
                        ],
                        Text(
                          title,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: _titleFontSize(),
                            fontWeight: FontWeight.bold,
                            height: 1.2,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 6),
                          subtitle!,
                        ],
                        if (meta != null) ...[
                          const SizedBox(height: 12),
                          meta!,
                        ],
                        if (actions != null) ...[
                          const SizedBox(height: 16),
                          actions!,
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
            stretchModes: const [StretchMode.zoomBackground],
          );
        },
      ),
      leading:
          leading ??
          IconButton(
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.4),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_back, color: Colors.white),
            ),
            onPressed: () => Navigator.pop(context),
          ),
      actions: appBarActions,
    );
  }
}

/// White "play" pill + translucent shuffle circle used by the local and
/// downloaded album headers.
class AlbumPlayActions extends StatelessWidget {
  const AlbumPlayActions({
    super.key,
    required this.playLabel,
    required this.shuffleTooltip,
    required this.onPlay,
    required this.onShuffle,
  });

  final String playLabel;
  final String shuffleTooltip;
  final VoidCallback onPlay;
  final VoidCallback onShuffle;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(
          child: FilledButton.icon(
            onPressed: onPlay,
            icon: const Icon(Icons.play_arrow, size: 20),
            label: Text(
              playLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black87,
              minimumSize: const Size(0, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            tooltip: shuffleTooltip,
            onPressed: onShuffle,
            icon: const Icon(Icons.shuffle, color: Colors.white),
          ),
        ),
      ],
    );
  }
}

/// "•"-joined row of white [HeaderMetaItem]s shown under the header subtitle
/// (track count, duration, quality, ...).
class HeaderMetaRow extends StatelessWidget {
  const HeaderMetaRow({super.key, required this.items});

  final List<Widget> items;

  @override
  Widget build(BuildContext context) {
    final parts = <Widget>[];
    for (final item in items) {
      if (parts.isNotEmpty) {
        parts.add(
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              '•',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
        );
      }
      parts.add(item);
    }

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: 4,
      children: parts,
    );
  }
}

/// Single white meta label (optional leading icon) for [HeaderMetaRow].
class HeaderMetaItem extends StatelessWidget {
  const HeaderMetaItem(this.label, {super.key, this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    const textStyle = TextStyle(
      color: Colors.white,
      fontSize: 13,
      fontWeight: FontWeight.w500,
    );
    if (icon == null) return Text(label, style: textStyle);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: Colors.white),
        const SizedBox(width: 4),
        Text(label, style: textStyle),
      ],
    );
  }
}
