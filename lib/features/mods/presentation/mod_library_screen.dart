import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:bamm/features/mods/application/mod_apply_controller.dart';
import 'package:bamm/features/mods/application/mod_import_controller.dart';
import 'package:bamm/features/mods/application/providers.dart';
import 'package:bamm/features/mods/domain/entities/mod_asset_category.dart';
import 'package:bamm/features/mods/domain/entities/mod_compatibility.dart';
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Import failed: ${next.error}')));
        ref.read(modImportControllerProvider.notifier).clearError();
      }

      if (prev != null &&
          prev.isImporting &&
          !next.isImporting &&
          next.error == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Import complete')));
      }
    });

    ref.listen<ModApplyState>(modApplyControllerProvider, (prev, next) {
      if (next.error != null && prev?.error != next.error) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${next.error}')));
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
                  LinearProgressIndicator(value: importState.progress),
                ],
              ),
            ),
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
          Expanded(
            child: modsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 48,
                        color: colorScheme.error,
                      ),
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
                        Icon(
                          Icons.extension_off,
                          size: 64,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No mods yet',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Imported mods will be grouped by student, shared asset type, and variant automatically.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium
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

                final groups = _groupMods(mods);
                final matchedCount = mods
                    .where((mod) => mod.hasStudentMatch)
                    .length;
                final manualOverrideCount = mods
                    .where((mod) => mod.hasManualTargetOverride)
                    .length;
                final unsupportedCount = mods
                    .where(
                      (mod) =>
                          mod.compatibilityStatus ==
                          ModCompatibilityStatus.unsupported,
                    )
                    .length;
                final pendingMods = mods
                    .where((mod) => !mod.isApplied)
                    .toList(growable: false);
                final appliedMods = mods
                    .where((mod) => mod.isApplied)
                    .toList(growable: false);

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                  children: [
                    _LibrarySummaryCard(
                      totalCount: mods.length,
                      matchedCount: matchedCount,
                      unsupportedCount: unsupportedCount,
                      manualOverrideCount: manualOverrideCount,
                      applyAllLabel: 'Apply all (${pendingMods.length})',
                      restoreAllLabel: 'Restore all (${appliedMods.length})',
                      onApplyAll: pendingMods.isEmpty || applyState.isApplying
                          ? null
                          : () async {
                              final result = await ref
                                  .read(modApplyControllerProvider.notifier)
                                  .applyAllMods(mods);
                              if (!context.mounted) {
                                return;
                              }
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    _buildBatchMessage(
                                      actionLabel: 'Applied',
                                      result: result,
                                      emptyLabel: 'No unapplied mods to apply',
                                    ),
                                  ),
                                ),
                              );
                            },
                      onRestoreAll: appliedMods.isEmpty || applyState.isApplying
                          ? null
                          : () async {
                              final result = await ref
                                  .read(modApplyControllerProvider.notifier)
                                  .restoreAllMods(mods);
                              if (!context.mounted) {
                                return;
                              }
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    _buildBatchMessage(
                                      actionLabel: 'Restored',
                                      result: result,
                                      emptyLabel: 'No applied mods to restore',
                                    ),
                                  ),
                                ),
                              );
                            },
                    ),
                    const SizedBox(height: 12),
                    for (final group in groups) ...[
                      _GroupHeader(group: group),
                      const SizedBox(height: 8),
                      for (final mod in group.mods) ...[
                        _ModCard(mod: mod),
                        const SizedBox(height: 8),
                      ],
                      const SizedBox(height: 8),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<_ModGroup> _groupMods(List<ModEntry> mods) {
    final sortedMods = [...mods]
      ..sort((left, right) {
        final groupCompare = left.libraryGroupLabel.toLowerCase().compareTo(
          right.libraryGroupLabel.toLowerCase(),
        );
        if (groupCompare != 0) {
          return groupCompare;
        }

        return left.name.toLowerCase().compareTo(right.name.toLowerCase());
      });

    final grouped = <String, List<ModEntry>>{};
    for (final mod in sortedMods) {
      grouped.putIfAbsent(mod.libraryGroupLabel, () => []).add(mod);
    }

    final groups = grouped.entries
        .map(
          (entry) => _ModGroup(
            title: entry.key,
            mods: entry.value,
            kind: _groupKindForMods(entry.value),
          ),
        )
        .toList(growable: false);

    groups.sort((left, right) {
      if (left.kind != right.kind) {
        return left.kind.sortOrder.compareTo(right.kind.sortOrder);
      }
      return left.title.toLowerCase().compareTo(right.title.toLowerCase());
    });

    return groups;
  }

  _ModGroupKind _groupKindForMods(List<ModEntry> mods) {
    final sample = mods.first;
    if (sample.hasStudentMatch) {
      return _ModGroupKind.student;
    }
    if (sample.needsAttention) {
      return _ModGroupKind.needsAttention;
    }
    return _ModGroupKind.shared;
  }

  String _buildBatchMessage({
    required String actionLabel,
    required ModBatchActionResult result,
    required String emptyLabel,
  }) {
    if (result.attemptedCount == 0) {
      return emptyLabel;
    }
    if (result.failureCount == 0) {
      return '$actionLabel ${result.successCount} mods';
    }

    return '$actionLabel ${result.successCount}/${result.attemptedCount} mods';
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
    final importedDateFormat = DateFormat.yMMMd();
    final assetDateFormat = DateFormat('yyyy-MM-dd');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  mod.isApplied ? Icons.check_circle : Icons.extension,
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
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _StatusChip(
                  label: mod.compatibilityStatus.label,
                  icon: _compatibilityIcon(mod.compatibilityStatus),
                  color: _compatibilityColor(context, mod.compatibilityStatus),
                ),
                if (mod.hasStudentMatch)
                  _StatusChip(
                    label: mod.studentGroupLabel,
                    icon: Icons.person,
                    color: colorScheme.primaryContainer,
                  ),
                _StatusChip(
                  label: mod.assetCategory.label,
                  icon: _assetCategoryIcon(mod.assetCategory),
                  color: colorScheme.surfaceContainerHighest,
                ),
                if (mod.assetVariantLabel != null)
                  _StatusChip(
                    label: mod.assetVariantLabel!,
                    icon: Icons.sell_outlined,
                    color: colorScheme.tertiaryContainer,
                  ),
                _StatusChip(
                  label: mod.hasManualTargetOverride
                      ? 'Manual target override'
                      : 'Using filename target',
                  icon: mod.hasManualTargetOverride
                      ? Icons.edit_location_alt
                      : Icons.auto_fix_high,
                  color: mod.hasManualTargetOverride
                      ? colorScheme.secondaryContainer
                      : colorScheme.surfaceContainerHighest,
                ),
                if (mod.isChunked)
                  _StatusChip(
                    label:
                        'Chunk ${mod.chunkIndex!.toString().padLeft(3, '0')}',
                    icon: Icons.view_stream,
                    color: colorScheme.surfaceContainerHighest,
                  ),
                if (mod.assetDate != null)
                  _StatusChip(
                    label: assetDateFormat.format(mod.assetDate!),
                    icon: Icons.event,
                    color: colorScheme.surfaceContainerHighest,
                  ),
                if (mod.isApplied)
                  _StatusChip(
                    label: 'Applied',
                    icon: Icons.check_circle,
                    color: Colors.green.withValues(alpha: 0.15),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _InfoRow(label: 'File', value: mod.originalFileName),
            if (mod.assetFamilyLabel != null)
              _InfoRow(label: 'Family', value: mod.assetFamilyLabel!),
            _InfoRow(label: 'Target', value: mod.targetFile),
            if (mod.compatibilityReason != null)
              _InfoRow(label: 'Compat', value: mod.compatibilityReason!),
            _InfoRow(label: 'Size', value: _formatSize(mod.sizeBytes)),
            _InfoRow(
              label: 'Imported',
              value: importedDateFormat.format(mod.importedAt),
            ),
            if (mod.studentDevName != null)
              _InfoRow(label: 'Dev name', value: mod.studentDevName!),
            if (mod.chunkGroupId != null)
              _InfoRow(label: 'Group key', value: mod.chunkGroupId!),
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
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (mod.isApplied)
                    FilledButton.tonalIcon(
                      onPressed: () async {
                        final success = await ref
                            .read(modApplyControllerProvider.notifier)
                            .restoreMod(mod);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                success
                                    ? 'Restored original file'
                                    : 'Failed to restore',
                              ),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.restore, size: 16),
                      label: const Text('Restore'),
                    )
                  else
                    FilledButton.icon(
                      onPressed: shizukuReady
                          ? () async {
                              final result = await ref
                                  .read(modApplyControllerProvider.notifier)
                                  .applyMod(mod);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      result.success
                                          ? 'Mod applied successfully'
                                          : result.errorMessage ??
                                                'Failed to apply',
                                    ),
                                  ),
                                );
                              }
                            }
                          : null,
                      icon: const Icon(Icons.play_arrow, size: 16),
                      label: const Text('Apply'),
                    ),
                  OutlinedButton.icon(
                    onPressed: () => _showSetTargetDialog(context, ref),
                    icon: const Icon(Icons.gps_fixed, size: 16),
                    label: Text(
                      mod.hasManualTargetOverride
                          ? 'Change Override'
                          : 'Override Target',
                    ),
                  ),
                  if (mod.hasManualTargetOverride)
                    TextButton.icon(
                      onPressed: () => ref
                          .read(modLibraryControllerProvider.notifier)
                          .clearModTargetOverride(mod.id),
                      icon: const Icon(Icons.undo, size: 16),
                      label: const Text('Use detected target'),
                    ),
                  IconButton(
                    onPressed: () => _showDeleteDialog(context, ref),
                    icon: Icon(
                      Icons.delete_outline,
                      size: 20,
                      color: colorScheme.error,
                    ),
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
    final controller = TextEditingController(
      text: mod.hasManualTargetOverride ? mod.targetFile : '',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Override Target File'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: 'Target file path',
                hintText: mod.originalFileName,
                helperText: 'Leave blank to use the detected filename target.',
                border: const OutlineInputBorder(),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              ref
                  .read(modLibraryControllerProvider.notifier)
                  .updateModTarget(mod.id, controller.text);
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
              ref.read(modLibraryControllerProvider.notifier).deleteMod(mod.id);
              Navigator.of(ctx).pop();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  IconData _assetCategoryIcon(ModAssetCategory category) {
    switch (category) {
      case ModAssetCategory.character:
        return Icons.face;
      case ModAssetCategory.skill:
        return Icons.auto_awesome;
      case ModAssetCategory.ui:
        return Icons.dashboard_customize;
      case ModAssetCategory.audio:
        return Icons.graphic_eq;
      case ModAssetCategory.effect:
        return Icons.blur_on;
      case ModAssetCategory.environment:
        return Icons.landscape;
      case ModAssetCategory.shared:
        return Icons.layers;
      case ModAssetCategory.unknown:
        return Icons.help_outline;
    }
  }

  IconData _compatibilityIcon(ModCompatibilityStatus status) {
    switch (status) {
      case ModCompatibilityStatus.compatible:
        return Icons.verified;
      case ModCompatibilityStatus.needsReview:
        return Icons.rule_folder;
      case ModCompatibilityStatus.unsupported:
        return Icons.warning_amber;
    }
  }

  Color _compatibilityColor(
    BuildContext context,
    ModCompatibilityStatus status,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    switch (status) {
      case ModCompatibilityStatus.compatible:
        return Colors.green.withValues(alpha: 0.15);
      case ModCompatibilityStatus.needsReview:
        return colorScheme.tertiaryContainer;
      case ModCompatibilityStatus.unsupported:
        return colorScheme.errorContainer;
    }
  }
}

class _LibrarySummaryCard extends StatelessWidget {
  const _LibrarySummaryCard({
    required this.totalCount,
    required this.matchedCount,
    required this.unsupportedCount,
    required this.manualOverrideCount,
    required this.applyAllLabel,
    required this.restoreAllLabel,
    required this.onApplyAll,
    required this.onRestoreAll,
  });

  final int totalCount;
  final int matchedCount;
  final int unsupportedCount;
  final int manualOverrideCount;
  final String applyAllLabel;
  final String restoreAllLabel;
  final Future<void> Function()? onApplyAll;
  final Future<void> Function()? onRestoreAll;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _SummaryMetric(
                    label: 'Mods',
                    value: '$totalCount',
                    icon: Icons.extension,
                  ),
                ),
                Expanded(
                  child: _SummaryMetric(
                    label: 'Matched',
                    value: '$matchedCount',
                    icon: Icons.person,
                  ),
                ),
                Expanded(
                  child: _SummaryMetric(
                    label: 'Unsupported',
                    value: '$unsupportedCount',
                    icon: Icons.warning_amber,
                  ),
                ),
                Expanded(
                  child: _SummaryMetric(
                    label: 'Overrides',
                    value: '$manualOverrideCount',
                    icon: Icons.edit_location_alt,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: onApplyAll,
                  icon: const Icon(Icons.playlist_add_check),
                  label: Text(applyAllLabel),
                ),
                FilledButton.tonalIcon(
                  onPressed: onRestoreAll,
                  icon: const Icon(Icons.restore_page),
                  label: Text(restoreAllLabel),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Icon(icon, color: colorScheme.primary),
        const SizedBox(height: 4),
        Text(value, style: Theme.of(context).textTheme.titleMedium),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.group});

  final _ModGroup group;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Expanded(
          child: Text(
            group.title,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: group.isUnmatched
                ? colorScheme.surfaceContainerHighest
                : group.isShared
                ? colorScheme.secondaryContainer
                : colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '${group.mods.length}',
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14),
          const SizedBox(width: 4),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
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

class _ModGroup {
  const _ModGroup({
    required this.title,
    required this.mods,
    required this.kind,
  });

  final String title;
  final List<ModEntry> mods;
  final _ModGroupKind kind;

  bool get isUnmatched => kind == _ModGroupKind.needsAttention;
  bool get isShared => kind == _ModGroupKind.shared;
}

enum _ModGroupKind {
  student(0),
  shared(1),
  needsAttention(2);

  const _ModGroupKind(this.sortOrder);

  final int sortOrder;
}
