import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:bamm/core/constants/app_constants.dart';
import 'package:bamm/features/game_data/application/providers.dart';
import 'package:bamm/features/launch/application/launch_controller.dart';
import 'package:bamm/features/launch/application/providers.dart';
import 'package:bamm/features/mods/application/mod_import_controller.dart';
import 'package:bamm/features/mods/application/providers.dart';
import 'package:bamm/features/shizuku/application/providers.dart';
import 'package:bamm/features/shizuku/application/shizuku_state.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(shizukuControllerProvider.notifier).initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    final shizukuState = ref.watch(shizukuControllerProvider);
    final gameInstallAsync = ref.watch(gameInstallControllerProvider);
    final modsAsync = ref.watch(modLibraryControllerProvider);
    final backupsAsync = ref.watch(backupControllerProvider);
    final launchState = ref.watch(launchControllerProvider);
    final importState = ref.watch(modImportControllerProvider);
    final colorScheme = Theme.of(context).colorScheme;

    // Show snackbar on launch error
    ref.listen<LaunchState>(launchControllerProvider, (prev, next) {
      if (next.error != null && prev?.error != next.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.error!)),
        );
      }
      if (next.lastLaunchSuccess == true &&
          prev?.lastLaunchSuccess != true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Game launched successfully')),
        );
      }
    });

    // Show snackbar on import error
    ref.listen<ModImportState>(modImportControllerProvider, (prev, next) {
      if (next.error != null && prev?.error != next.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: ${next.error}')),
        );
        ref.read(modImportControllerProvider.notifier).clearError();
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('BAMM')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Shizuku Status Card
          _ShizukuCard(state: shizukuState, colorScheme: colorScheme),
          const SizedBox(height: 12),

          // Game Install Card
          _GameInstallCard(
            gameInstallAsync: gameInstallAsync,
            colorScheme: colorScheme,
          ),
          const SizedBox(height: 12),

          // Quick Actions
          _QuickActionsCard(
            shizukuReady: shizukuState.isReady,
            gameInstallAsync: gameInstallAsync,
            launchState: launchState,
            importState: importState,
            colorScheme: colorScheme,
          ),
          const SizedBox(height: 12),

          // Status Bar
          _StatusCard(
            modsAsync: modsAsync,
            backupsAsync: backupsAsync,
            colorScheme: colorScheme,
          ),
        ],
      ),
    );
  }
}

class _ShizukuCard extends ConsumerWidget {
  const _ShizukuCard({required this.state, required this.colorScheme});

  final ShizukuState state;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  state.isReady ? Icons.check_circle : Icons.link,
                  color: state.isReady
                      ? Colors.green
                      : colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Shizuku',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (state.version != null)
                  Text(
                    'v${state.version}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _statusText(state.status),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
            if (state.errorMessage != null) ...[
              const SizedBox(height: 4),
              Text(
                state.errorMessage!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.error,
                    ),
              ),
            ],
            if (state.isLoading) ...[
              const SizedBox(height: 8),
              const LinearProgressIndicator(),
            ],
            if (!state.isReady && !state.isLoading) ...[
              const SizedBox(height: 12),
              _buildActionButton(context, ref),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(shizukuControllerProvider.notifier);

    switch (state.status) {
      case ShizukuStatus.unknown:
      case ShizukuStatus.notInstalled:
      case ShizukuStatus.installed:
        return FilledButton.tonal(
          onPressed: () => notifier.initialize(),
          child: const Text('Connect'),
        );
      case ShizukuStatus.binderAlive:
        return FilledButton.tonal(
          onPressed: () => notifier.requestPermission(),
          child: const Text('Grant Permission'),
        );
      case ShizukuStatus.permissionGranted:
        return FilledButton.tonal(
          onPressed: () => notifier.bindService(),
          child: const Text('Bind Service'),
        );
      case ShizukuStatus.serviceBound:
        return const SizedBox.shrink();
    }
  }

  String _statusText(ShizukuStatus status) {
    switch (status) {
      case ShizukuStatus.unknown:
        return 'Status unknown — tap Connect to check';
      case ShizukuStatus.notInstalled:
        return 'Shizuku is not installed or not running';
      case ShizukuStatus.installed:
        return 'Shizuku is installed';
      case ShizukuStatus.binderAlive:
        return 'Shizuku is running — permission needed';
      case ShizukuStatus.permissionGranted:
        return 'Permission granted — bind service to continue';
      case ShizukuStatus.serviceBound:
        return 'Connected and ready';
    }
  }
}

class _GameInstallCard extends ConsumerWidget {
  const _GameInstallCard({
    required this.gameInstallAsync,
    required this.colorScheme,
  });

  final AsyncValue<dynamic> gameInstallAsync;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.sports_esports, color: colorScheme.primary),
                const SizedBox(width: 12),
                Text(
                  'Game Installations',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            gameInstallAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: LinearProgressIndicator(),
              ),
              error: (error, _) => Text(
                'Error: $error',
                style: TextStyle(color: colorScheme.error),
              ),
              data: (state) {
                if (state.installations.isEmpty) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'No installations detected',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(height: 8),
                      FilledButton.tonal(
                        onPressed: () {
                          ref
                              .read(gameInstallControllerProvider.notifier)
                              .detectInstallations();
                        },
                        child: const Text('Detect'),
                      ),
                    ],
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (state.installations.length > 1) ...[
                      SegmentedButton<GameRegion>(
                        segments: state.installations
                            .map((i) => ButtonSegment(
                                  value: i.region,
                                  label: Text(i.region.displayName),
                                ))
                            .toList(),
                        selected: state.selectedRegion != null
                            ? {state.selectedRegion!}
                            : {},
                        onSelectionChanged: (selected) {
                          ref
                              .read(gameInstallControllerProvider.notifier)
                              .selectRegion(selected.first);
                        },
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (state.selectedInstall != null) ...[
                      Text(
                        state.selectedInstall!.packageName,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        state.selectedInstall!.gameDataPath,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            state.selectedInstall!.isAccessible
                                ? Icons.check_circle_outline
                                : Icons.warning_amber,
                            size: 16,
                            color: state.selectedInstall!.isAccessible
                                ? Colors.green
                                : Colors.orange,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            state.selectedInstall!.isAccessible
                                ? 'Accessible'
                                : 'Not accessible',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: state.selectedInstall!.isAccessible
                                          ? Colors.green
                                          : Colors.orange,
                                    ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () {
                        ref
                            .read(gameInstallControllerProvider.notifier)
                            .detectInstallations();
                      },
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Rescan'),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionsCard extends ConsumerWidget {
  const _QuickActionsCard({
    required this.shizukuReady,
    required this.gameInstallAsync,
    required this.launchState,
    required this.importState,
    required this.colorScheme,
  });

  final bool shizukuReady;
  final AsyncValue<dynamic> gameInstallAsync;
  final LaunchState launchState;
  final ModImportState importState;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedRegion = gameInstallAsync.valueOrNull?.selectedRegion;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick Actions',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            if (importState.isImporting) ...[
              Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 8),
                  Text('Importing ${importState.currentFile ?? '...'}'),
                ],
              ),
              if (importState.progress != null) ...[
                const SizedBox(height: 4),
                LinearProgressIndicator(value: importState.progress),
              ],
              const SizedBox(height: 12),
            ],
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: selectedRegion != null && !launchState.isLaunching
                      ? () {
                          ref
                              .read(launchControllerProvider.notifier)
                              .launchGame(selectedRegion);
                        }
                      : null,
                  icon: launchState.isLaunching
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.play_arrow),
                  label: const Text('Launch Game'),
                ),
                FilledButton.tonalIcon(
                  onPressed: importState.isImporting
                      ? null
                      : () {
                          ref
                              .read(modImportControllerProvider.notifier)
                              .importFromFilePicker();
                        },
                  icon: const Icon(Icons.add),
                  label: const Text('Import Mod'),
                ),
                OutlinedButton.icon(
                  onPressed: () => context.go('/mods'),
                  icon: const Icon(Icons.extension),
                  label: const Text('Mod Library'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.modsAsync,
    required this.backupsAsync,
    required this.colorScheme,
  });

  final AsyncValue<List<dynamic>> modsAsync;
  final AsyncValue<List<dynamic>> backupsAsync;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final appliedCount = modsAsync.whenOrNull(
          data: (mods) => mods.where((m) => m.isApplied == true).length,
        ) ??
        0;
    final totalMods = modsAsync.whenOrNull(data: (mods) => mods.length) ?? 0;
    final backupCount =
        backupsAsync.whenOrNull(data: (backups) => backups.length) ?? 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: _StatusItem(
                icon: Icons.extension,
                label: 'Mods',
                value: '$totalMods',
                colorScheme: colorScheme,
              ),
            ),
            Expanded(
              child: _StatusItem(
                icon: Icons.check_circle_outline,
                label: 'Applied',
                value: '$appliedCount',
                colorScheme: colorScheme,
              ),
            ),
            Expanded(
              child: _StatusItem(
                icon: Icons.backup,
                label: 'Backups',
                value: '$backupCount',
                colorScheme: colorScheme,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusItem extends StatelessWidget {
  const _StatusItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.colorScheme,
  });

  final IconData icon;
  final String label;
  final String value;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: colorScheme.primary),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}
