import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spotiflac_android/l10n/l10n.dart';
import 'package:spotiflac_android/providers/extension_provider.dart';
import 'package:spotiflac_android/utils/adaptive_layout.dart';
import 'package:spotiflac_android/widgets/discard_changes_dialog.dart';
import 'package:spotiflac_android/widgets/priority_settings_scaffold.dart';
import 'package:spotiflac_android/widgets/reorderable_priority_item.dart';

class ProviderPriorityPage extends ConsumerStatefulWidget {
  const ProviderPriorityPage({super.key});

  @override
  ConsumerState<ProviderPriorityPage> createState() =>
      _ProviderPriorityPageState();
}

class _ProviderPriorityPageState extends ConsumerState<ProviderPriorityPage> {
  late List<String> _providers;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _loadProviders();
  }

  void _loadProviders() {
    final extState = ref.read(extensionProvider);
    final allProviders = ref
        .read(extensionProvider.notifier)
        .getAllDownloadProviders();

    if (extState.providerPriority.isNotEmpty) {
      _providers = List.from(extState.providerPriority);
      for (final provider in allProviders) {
        if (!_providers.contains(provider)) {
          _providers.add(provider);
        }
      }
      _providers.removeWhere((p) => !allProviders.contains(p));
    } else {
      _providers = allProviders;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PrioritySettingsScaffold(
      hasChanges: _hasChanges,
      title: context.l10n.providerPriorityTitle,
      description: context.l10n.providerPriorityDescription,
      descriptionPadding: const EdgeInsets.all(16),
      infoText: context.l10n.providerPriorityInfo,
      onSave: _saveChanges,
      onConfirmDiscard: showDiscardChangesDialog,
      slivers: [
        SliverPadding(
          padding: EdgeInsets.symmetric(
            horizontal: 16 + wideListInset(context),
          ),
          sliver: SliverReorderableList(
            itemCount: _providers.length,
            itemBuilder: (context, index) {
              final provider = _providers[index];
              final extension = ref
                  .read(extensionProvider)
                  .extensions
                  .where((ext) => ext.id == provider)
                  .firstOrNull;
              return ReorderablePriorityItem(
                key: ValueKey(provider),
                index: index,
                isFirst: index == 0,
                icon: Icons.extension,
                iconColor: Theme.of(context).colorScheme.secondary,
                name: extension?.displayName ?? provider,
                subtitle: context.l10n.providerExtension,
              );
            },
            onReorderItem: (oldIndex, newIndex) {
              setState(() {
                final item = _providers.removeAt(oldIndex);
                _providers.insert(newIndex, item);
                _hasChanges = true;
              });
            },
          ),
        ),
      ],
    );
  }

  Future<void> _saveChanges() async {
    await ref.read(extensionProvider.notifier).setProviderPriority(_providers);
    if (!mounted) return;
    setState(() {
      _hasChanges = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.snackbarProviderPrioritySaved)),
    );
  }
}
