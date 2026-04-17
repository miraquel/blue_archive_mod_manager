import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:bamm/features/catalog/application/providers.dart';
import 'package:bamm/features/settings/application/providers.dart';
import 'package:bamm/features/settings/application/validator_index_controller.dart';
import 'package:bamm/features/shizuku/application/providers.dart';
import 'package:bamm/features/shizuku/application/shizuku_state.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shizukuState = ref.watch(shizukuControllerProvider);
    final mappingAsync = ref.watch(mappingControllerProvider);
    final validatorIndexAsync = ref.watch(validatorIndexControllerProvider);
    final colorScheme = Theme.of(context).colorScheme;

    ref.listen<AsyncValue<ValidatorIndexState>>(
      validatorIndexControllerProvider,
      (previous, next) {
        final previousState = previous?.valueOrNull;
        final nextState = next.valueOrNull;
        if (previousState == null || nextState == null) {
          return;
        }

        if (previousState.isRebuilding &&
            !nextState.isRebuilding &&
            nextState.error == null &&
            nextState.statusMessage != null) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(nextState.statusMessage!)));
        }

        if (nextState.error != null && previousState.error != nextState.error) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Validator rebuild failed: ${nextState.error}'),
            ),
          );
        }
      },
    );

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

          // --- Compatibility Validator Section ---
          _SectionHeader(
            title: 'Compatibility Validator',
            colorScheme: colorScheme,
          ),
          validatorIndexAsync.when(
            loading: () => const ListTile(
              leading: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              title: Text('Loading validator index...'),
            ),
            error: (error, _) => ListTile(
              leading: Icon(Icons.error_outline, color: colorScheme.error),
              title: const Text('Failed to load validator index'),
              subtitle: Text(error.toString()),
            ),
            data: (validatorState) {
              final snapshot = validatorState.snapshot;
              final builtAt = snapshot?.builtAt;
              final subtitleLines = <String>[
                if (snapshot != null)
                  'Source: ${snapshot.sourceLabel} • ${snapshot.fileCount} files',
                if (snapshot?.sourcePath case final sourcePath?)
                  'Path: $sourcePath',
                if (builtAt != null)
                  'Built: ${DateFormat.yMMMd().add_jm().format(builtAt.toLocal())}',
                if (snapshot == null) 'No validator index loaded',
              ];

              return Column(
                children: [
                  ListTile(
                    leading: Icon(
                      snapshot?.isBundled ?? true
                          ? Icons.inventory_2_outlined
                          : Icons.storage,
                    ),
                    title: const Text('Active validator index'),
                    subtitle: Text(subtitleLines.join('\n')),
                    isThreeLine: subtitleLines.length >= 2,
                  ),
                  if (validatorState.isRebuilding)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: LinearProgressIndicator(),
                    ),
                  if (validatorState.statusMessage != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          validatorState.statusMessage!,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ),
                  if (validatorState.error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        validatorState.error!,
                        style: TextStyle(
                          color: colorScheme.error,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.tonalIcon(
                          onPressed:
                              validatorState.isRebuilding ||
                                  !shizukuState.isReady
                              ? null
                              : () => ref
                                    .read(
                                      validatorIndexControllerProvider.notifier,
                                    )
                                    .rebuildIndex(),
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('Rebuild validator index'),
                        ),
                      ],
                    ),
                  ),
                  if (!shizukuState.isReady)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Connect Shizuku to rebuild the index from the installed Global Android game data.',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                      ),
                    ),
                ],
              );
            },
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
