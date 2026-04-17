import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:bamm/features/mods/application/mod_apply_controller.dart';
import 'package:bamm/features/mods/application/mod_import_controller.dart';
import 'package:bamm/features/mods/application/providers.dart';
import 'package:bamm/features/mods/domain/entities/mod_entry.dart';
import 'package:bamm/features/shizuku/application/providers.dart';

class ModLibraryScreen extends ConsumerWidget {
  const ModLibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modsAsync = ref.watch(modLibraryControllerProvider);
    final importState = ref.watch(modImportControllerProvider);
    final applyState = ref.watch(modApplyControllerProvider);
    final colorScheme = Theme.of(context).colorScheme;

    ref.listen<ModImportState>(modImportControllerProvider, (prev, next) {
      if (next.error != null && prev?.error != next.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: ${next.error}')),
        );
        ref.read(modImportControllerProvider.notifier).clearError();
      }
      // Import finished successfully
      if (prev != null &&
          prev.isImporting &&
          !next.isImporting &&
          next.error == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Import complete')),
        );
      }
    });

    ref.listen<ModApplyState>(modApplyControllerProvider, (prev, next) {
      if (next.error != null && prev?.error != next.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${next.error}')),
        );
        ref.read(modApplyControllerProvider.notifier).clearError();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mod Library'),
        actions: [
          IconButton(
            onPressed: () =>
                ref.read(modLibraryControllerProvider.notifier).refresh(),
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: importState.isImporting
            ? null
            : () => ref
                .read(modImportControllerProvider.notifier)
                .importFromFilePicker(),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          // Import progress bar
          if (importState.isImporting)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Importing ${importState.currentFile ?? '...'}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: importState.progress,
                  ),
                ],
              ),
            ),

          // Apply progress bar
          if (applyState.isApplying)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    applyState.statusMessage ?? 'Applying...',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 4),
                  const LinearProgressIndicator(),
                ],
              ),
            ),

          // Mod list
          Expanded(
            child: modsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline,
                          size: 48, color: colorScheme.error),
                      const SizedBox(height: 16),
                      Text(
                        'Failed to load mods',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        error.toString(),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 16),
                      FilledButton.tonal(
                        onPressed: () => ref
                            .read(modLibraryControllerProvider.notifier)
                            .refresh(),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
              data: (mods) {
                if (mods.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.extension_off,
                            size: 64, color: colorScheme.onSurfaceVariant),
                        const SizedBox(height: 16),
                        Text(
                          'No mods yet',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap + to import mod files',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: () => ref
                              .read(modImportControllerProvider.notifier)
                              .importFromFilePicker(),
                          icon: const Icon(Icons.add),
                          label: const Text('Import Mods'),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 8,
                    bottom: 88,
                  ),
                  itemCount: mods.length,
                  itemBuilder: (context, index) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _ModCard(mod: mods[index]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ModCard extends ConsumerWidget {
  const _ModCard({required this.mod});

  final ModEntry mod;

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final shizukuReady = ref.watch(shizukuControllerProvider).isReady;
    final applyState = ref.watch(modApplyControllerProvider);
    final isBusy = applyState.isApplying && applyState.currentModId == mod.id;
    final dateFormat = DateFormat.yMMMd();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Icon(
                  mod.isApplied
                      ? Icons.check_circle
                      : Icons.extension,
                  color: mod.isApplied ? Colors.green : colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    mod.name,
                    style: Theme.of(context).textTheme.titleSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (mod.isApplied)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Applied',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Colors.green,
                          ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            // Info rows
            _InfoRow(label: 'File', value: mod.originalFileName),
            _InfoRow(label: 'Size', value: _formatSize(mod.sizeBytes)),
            _InfoRow(label: 'Imported', value: dateFormat.format(mod.importedAt)),
            if (mod.targetFile != null)
              _InfoRow(label: 'Target', value: mod.targetFile!),
            if (mod.description != null) ...[
              const SizedBox(height: 4),
              Text(
                mod.description!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],

            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 8),

            // Actions
            if (isBusy)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(8),
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  // Set target file
                  OutlinedButton.icon(
                    onPressed: () => _showSetTargetDialog(context, ref),
                    icon: const Icon(Icons.gps_fixed, size: 16),
                    label: Text(
                      mod.targetFile == null ? 'Set Target' : 'Change Target',
                    ),
                  ),
                  // Apply or Restore
                  if (mod.isApplied)
                    FilledButton.tonalIcon(
                      onPressed: () async {
                        final success = await ref
                            .read(modApplyControllerProvider.notifier)
                            .restoreMod(mod);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(success
                                  ? 'Restored original file'
                                  : 'Failed to restore'),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.restore, size: 16),
                      label: const Text('Restore'),
                    )
                  else if (mod.targetFile != null)
                    FilledButton.icon(
                      onPressed: shizukuReady
                          ? () async {
                              final result = await ref
                                  .read(modApplyControllerProvider.notifier)
                                  .applyMod(mod);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(result.success
                                        ? 'Mod applied successfully'
                                        : result.errorMessage ??
                                            'Failed to apply'),
                                  ),
                                );
                              }
                            }
                          : null,
                      icon: const Icon(Icons.play_arrow, size: 16),
                      label: const Text('Apply'),
                    ),
                  // Delete
                  IconButton(
                    onPressed: () => _showDeleteDialog(context, ref),
                    icon: Icon(Icons.delete_outline,
                        size: 20, color: colorScheme.error),
                    tooltip: 'Delete',
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  void _showSetTargetDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController(text: mod.targetFile ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Set Target File'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Target file path',
            hintText: 'e.g. MediaResources.unity3d',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final target = controller.text.trim();
              if (target.isNotEmpty) {
                ref
                    .read(modLibraryControllerProvider.notifier)
                    .updateModTarget(mod.id, target);
              }
              Navigator.of(ctx).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Mod'),
        content: Text('Delete "${mod.name}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () {
              ref
                  .read(modLibraryControllerProvider.notifier)
                  .deleteMod(mod.id);
              Navigator.of(ctx).pop();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodySmall,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
