import 'package:flutter/material.dart';
import 'package:spotiflac_android/l10n/l10n.dart';
import 'package:spotiflac_android/widgets/animation_utils.dart';

/// Shared track row for album-style screens: track number, selection
/// checkbox, title/subtitle, and a trailing play button that's replaced by
/// the checkbox once selection mode is active.
class AlbumTrackTile extends StatelessWidget {
  const AlbumTrackTile({
    super.key,
    required this.trackNumber,
    required this.trackName,
    required this.subtitle,
    required this.isSelectionMode,
    required this.isSelected,
    required this.colorScheme,
    required this.onToggleSelection,
    required this.onOpen,
    required this.onEnterSelectionMode,
    required this.onPlay,
  });

  final int? trackNumber;
  final String trackName;
  final Widget subtitle;
  final bool isSelectionMode;
  final bool isSelected;
  final ColorScheme colorScheme;
  final VoidCallback onToggleSelection;
  final VoidCallback onOpen;
  final VoidCallback onEnterSelectionMode;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Card(
        elevation: 0,
        color: isSelected
            ? colorScheme.primaryContainer.withValues(alpha: 0.3)
            : Colors.transparent,
        margin: const EdgeInsets.symmetric(vertical: 2),
        child: ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          onTap: isSelectionMode ? onToggleSelection : onOpen,
          onLongPress: isSelectionMode ? null : onEnterSelectionMode,
          leading: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isSelectionMode) ...[
                AnimatedSelectionCheckbox(
                  visible: true,
                  selected: isSelected,
                  colorScheme: colorScheme,
                  size: 24,
                ),
                const SizedBox(width: 12),
              ],
              SizedBox(
                width: 24,
                child: Text(
                  trackNumber?.toString() ?? '-',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
          title: Text(
            trackName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
          ),
          subtitle: subtitle,
          trailing: isSelectionMode
              ? null
              : IconButton(
                  tooltip: context.l10n.tooltipPlay,
                  onPressed: onPlay,
                  icon: Icon(Icons.play_arrow, color: colorScheme.primary),
                  style: IconButton.styleFrom(
                    backgroundColor: colorScheme.primaryContainer.withValues(
                      alpha: 0.3,
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
