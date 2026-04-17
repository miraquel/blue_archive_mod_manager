import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bamm/features/catalog/application/providers.dart';
import 'package:bamm/features/shizuku/application/providers.dart';
import 'package:bamm/features/shizuku/application/shizuku_state.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shizukuState = ref.watch(shizukuControllerProvider);
    final mappingAsync = ref.watch(mappingControllerProvider);
    final colorScheme = Theme.of(context).colorScheme;

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
                      style:
                          TextStyle(color: colorScheme.error, fontSize: 12),
                    ),
                  ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: colorScheme.primary,
            ),
      ),
    );
  }
}
