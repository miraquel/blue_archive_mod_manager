import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bamm/features/catalog/application/providers.dart';
import 'package:bamm/features/game_data/application/providers.dart';
import 'package:bamm/features/recovery/application/providers.dart';
import 'package:bamm/features/recovery/application/repair_controller.dart';
import 'package:bamm/features/shizuku/application/providers.dart';
import 'package:bamm/features/shizuku/application/shizuku_state.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shizukuState = ref.watch(shizukuControllerProvider);
    final mappingAsync = ref.watch(mappingControllerProvider);
    final repairState = ref.watch(repairControllerProvider);
    final backupsAsync = ref.watch(backupControllerProvider);
    final colorScheme = Theme.of(context).colorScheme;

    ref.listen<RepairState>(repairControllerProvider, (previous, next) {
      if (previous == null) return;

      // Show snackbar when a repair/scan operation completes
      if (previous.isBusy && !next.isBusy && next.error == null) {
        if (next.statusMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(next.statusMessage!)),
          );
        }
      }

      if (next.error != null && previous.error != next.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Recovery error: ${next.error}')),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          // --- Shizuku Section ---
          _SectionHeader(title: 'Shizuku', colorScheme: colorScheme),
          ListTile(
            leading: Icon(
              shizukuState.isReady ? Icons.check_circle : Icons.link_off,
              color: shizukuState.isReady ? Colors.green : colorScheme.error,
            ),
            title: const Text('Status'),
            subtitle: Text(_shizukuStatusLabel(shizukuState.status)),
            trailing: shizukuState.version != null
                ? Text('v${shizukuState.version}')
                : null,
          ),
          if (shizukuState.isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: LinearProgressIndicator(),
            ),
          if (shizukuState.errorMessage != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                shizukuState.errorMessage!,
                style: TextStyle(color: colorScheme.error, fontSize: 12),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Wrap(
              spacing: 8,
              children: [
                if (!shizukuState.isReady)
                  FilledButton.tonal(
                    onPressed: shizukuState.isLoading
                        ? null
                        : () => ref
                              .read(shizukuControllerProvider.notifier)
                              .initialize(),
                    child: const Text('Connect'),
                  ),
                if (shizukuState.isReady)
                  OutlinedButton(
                    onPressed: shizukuState.isLoading
                        ? null
                        : () => ref
                              .read(shizukuControllerProvider.notifier)
                              .unbindService(),
                    child: const Text('Disconnect'),
                  ),
              ],
            ),
          ),
          const Divider(),

          // --- Catalog Mapping Section ---
          _SectionHeader(title: 'Catalog Mapping', colorScheme: colorScheme),
          mappingAsync.when(
            loading: () => const ListTile(
              leading: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              title: Text('Loading mappings...'),
            ),
            error: (error, _) => ListTile(
              leading: Icon(Icons.error_outline, color: colorScheme.error),
              title: const Text('Failed to load mappings'),
              subtitle: Text(error.toString()),
            ),
            data: (mappingState) => Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.map),
                  title: const Text('Loaded Mappings'),
                  subtitle: Text(
                    mappingState.isLoaded
                        ? '${mappingState.mappings.length} asset mappings'
                        : 'No mappings loaded',
                  ),
                ),
                if (mappingState.isImporting)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: LinearProgressIndicator(),
                  ),
                if (mappingState.error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      mappingState.error!,
                      style: TextStyle(color: colorScheme.error, fontSize: 12),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Wrap(
                    spacing: 8,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: mappingState.isImporting
                            ? null
                            : () => ref
                                  .read(mappingControllerProvider.notifier)
                                  .importMappingFile(),
                        icon: const Icon(Icons.file_open, size: 18),
                        label: const Text('Import Mapping.json'),
                      ),
                      if (mappingState.isLoaded)
                        OutlinedButton.icon(
                          onPressed: mappingState.isImporting
                              ? null
                              : () => ref
                                    .read(mappingControllerProvider.notifier)
                                    .clearMappings(),
                          icon: const Icon(Icons.clear, size: 18),
                          label: const Text('Clear'),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(),

          // --- Recovery Section ---
          _SectionHeader(title: 'Game Recovery', colorScheme: colorScheme),
          _buildRecoverySection(
            context,
            ref,
            repairState,
            backupsAsync,
            shizukuState,
            colorScheme,
          ),
          const Divider(),

          // --- About Section ---
          _SectionHeader(title: 'About', colorScheme: colorScheme),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('BAMM - Blue Archive Mod Manager'),
            subtitle: Text('Version 1.0.0'),
          ),
        ],
      ),
    );
  }

  Widget _buildRecoverySection(
    BuildContext context,
    WidgetRef ref,
    RepairState repairState,
    AsyncValue<dynamic> backupsAsync,
    ShizukuState shizukuState,
    ColorScheme colorScheme,
  ) {
    final backupCount =
        backupsAsync.valueOrNull is List ? (backupsAsync.value as List).length : 0;
    final diff = repairState.lastDiff;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Status info
        ListTile(
          leading: Icon(
            diff != null
                ? (diff.isClean ? Icons.verified : Icons.warning_amber)
                : Icons.shield_outlined,
            color: diff != null
                ? (diff.isClean ? Colors.green : Colors.orange)
                : null,
          ),
          title: const Text('Game file integrity'),
          subtitle: Text(
            diff != null
                ? (diff.isClean
                    ? '${diff.totalManifestFiles} files verified'
                    : '${diff.repairableCount} file(s) need repair')
                : 'Not scanned yet',
          ),
        ),

        if (backupCount > 0)
          ListTile(
            leading: const Icon(Icons.backup),
            title: const Text('Backups'),
            subtitle: Text('$backupCount backup(s) stored locally'),
          ),

        // Progress
        if (repairState.isBusy)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const LinearProgressIndicator(),
                if (repairState.statusMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      repairState.statusMessage!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
              ],
            ),
          ),

        if (!repairState.isBusy && repairState.statusMessage != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              repairState.statusMessage!,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),

        if (repairState.error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              repairState.error!,
              style: TextStyle(color: colorScheme.error, fontSize: 12),
            ),
          ),

        // Version info
        if (repairState.versionInfo != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Latest: v${repairState.versionInfo!.latestBuildVersion} '
              '(patch ${repairState.versionInfo!.patchVersion})',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
          ),

        // Action buttons
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              // Scan for issues
              FilledButton.tonalIcon(
                onPressed: repairState.isBusy || !shizukuState.isReady
                    ? null
                    : () => ref
                          .read(repairControllerProvider.notifier)
                          .scanForIssues(),
                icon: const Icon(Icons.search, size: 18),
                label: const Text('Scan for issues'),
              ),

              // Repair from official source
              if (diff != null && !diff.isClean)
                FilledButton.icon(
                  onPressed: repairState.isBusy
                      ? null
                      : () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Repair game files?'),
                              content: Text(
                                'This will download and replace '
                                '${diff.repairableCount} file(s) from the '
                                'official source. Continue?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Cancel'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('Repair'),
                                ),
                              ],
                            ),
                          );
                          if (confirmed == true) {
                            ref
                                .read(repairControllerProvider.notifier)
                                .repairFromManifest();
                          }
                        },
                  icon: const Icon(Icons.build, size: 18),
                  label: Text('Repair ${diff.repairableCount} file(s)'),
                ),

              // Restore all backups
              if (backupCount > 0)
                OutlinedButton.icon(
                  onPressed: repairState.isBusy
                      ? null
                      : () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Restore all backups?'),
                              content: Text(
                                'This will restore $backupCount backup(s) to '
                                'their original game data locations, undoing '
                                'any applied mods. Continue?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Cancel'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('Restore'),
                                ),
                              ],
                            ),
                          );
                          if (confirmed == true) {
                            ref
                                .read(repairControllerProvider.notifier)
                                .restoreAllBackups();
                          }
                        },
                  icon: const Icon(Icons.restore, size: 18),
                  label: const Text('Restore all backups'),
                ),
            ],
          ),
        ),

        if (!shizukuState.isReady)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Connect Shizuku to scan and repair game files.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
          ),
      ],
    );
  }

  String _shizukuStatusLabel(ShizukuStatus status) {
    switch (status) {
      case ShizukuStatus.unknown:
        return 'Unknown';
      case ShizukuStatus.notInstalled:
        return 'Not installed or not running';
      case ShizukuStatus.installed:
        return 'Installed';
      case ShizukuStatus.binderAlive:
        return 'Running — permission needed';
      case ShizukuStatus.permissionGranted:
        return 'Permission granted';
      case ShizukuStatus.serviceBound:
        return 'Connected';
    }
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.colorScheme});

  final String title;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleSmall?.copyWith(color: colorScheme.primary),
      ),
    );
  }
}
