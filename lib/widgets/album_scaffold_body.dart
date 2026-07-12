import 'package:flutter/material.dart';

/// Shared body for album-style screens: a [PopScope] that exits selection
/// mode instead of popping, a scrollable track list, and a bottom-select bar
/// that slides in over it.
class AlbumScaffoldBody extends StatelessWidget {
  const AlbumScaffoldBody({
    super.key,
    required this.scrollController,
    required this.isSelectionMode,
    required this.onExitSelectionMode,
    required this.appBar,
    required this.trackList,
    required this.bottomBar,
    required this.bottomInset,
    required this.bottomPadding,
  });

  final ScrollController scrollController;
  final bool isSelectionMode;
  final VoidCallback onExitSelectionMode;
  final Widget appBar;
  final Widget trackList;
  final Widget bottomBar;
  final double bottomInset;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !isSelectionMode,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && isSelectionMode) {
          onExitSelectionMode();
        }
      },
      child: Scaffold(
        body: Stack(
          children: [
            CustomScrollView(
              controller: scrollController,
              slivers: [
                appBar,
                trackList,
                SliverToBoxAdapter(
                  child: SizedBox(height: isSelectionMode ? 120 : 32),
                ),
                SliverToBoxAdapter(child: SizedBox(height: bottomInset)),
              ],
            ),

            AnimatedPositioned(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              left: 0,
              right: 0,
              bottom: isSelectionMode ? 0 : -(200 + bottomPadding),
              child: bottomBar,
            ),
          ],
        ),
      ),
    );
  }
}
