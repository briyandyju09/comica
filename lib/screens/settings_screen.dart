import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/library_provider.dart';
import '../services/cover_cache_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isClearingCache = false;

  Future<void> _changeFolder() async {
    HapticFeedback.lightImpact();
    final result = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select comics folder',
    );
    if (result != null && mounted) {
      await ref.read(appSettingsProvider.notifier).setRootDirectory(result);
      await ref.read(libraryProvider.notifier).scanLibrary(result);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Library folder updated')),
        );
      }
    }
  }

  Future<void> _clearCache() async {
    setState(() => _isClearingCache = true);
    try {
      final coverCache = ref.read(coverCacheServiceProvider);
      await coverCache.clearCache();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cover cache cleared')),
        );
      }
    } finally {
      if (mounted) setState(() => _isClearingCache = false);
    }
  }

  Future<void> _clearLibrary() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear Library?'),
        content: const Text(
          'This will remove all comics, reading progress, and favorites from the app. Your files will not be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await ref.read(storageServiceProvider).clearLibrary();
      await ref.read(appSettingsProvider.notifier).setRootDirectory('');
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Library section
          _SectionHeader(label: 'Library', theme: theme),
          _SettingsCard(
            colorScheme: colorScheme,
            children: [
              ListTile(
                leading: Icon(Icons.folder_open_rounded, color: colorScheme.primary),
                title: const Text('Comics Folder'),
                subtitle: Text(
                  settings.rootDirectoryPath ?? 'Not selected',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: _changeFolder,
              ),
              const Divider(height: 1, indent: 56),
              ListTile(
                leading: Icon(Icons.sync_rounded, color: colorScheme.primary),
                title: const Text('Refresh Library'),
                subtitle: const Text('Scan for new or removed comics'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  HapticFeedback.lightImpact();
                  ref.read(libraryProvider.notifier).refreshLibrary();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Scanning library...')),
                  );
                },
              ),
            ],
          ),

          // Reading section
          _SectionHeader(label: 'Reading', theme: theme),
          _SettingsCard(
            colorScheme: colorScheme,
            children: [
              SwitchListTile(
                secondary: Icon(Icons.swap_vert_rounded, color: colorScheme.primary),
                title: const Text('Vertical Scroll'),
                subtitle: const Text('Scroll up/down instead of swipe'),
                value: settings.useVerticalScroll,
                onChanged: (v) {
                  ref.read(appSettingsProvider.notifier).setScrollMode(v);
                },
              ),
            ],
          ),

          // Storage section
          _SectionHeader(label: 'Storage', theme: theme),
          _SettingsCard(
            colorScheme: colorScheme,
            children: [
              ListTile(
                leading: Icon(Icons.image_rounded, color: colorScheme.primary),
                title: const Text('Clear Cover Cache'),
                subtitle: const Text('Re-generates all comic covers'),
                trailing: _isClearingCache
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : const Icon(Icons.chevron_right_rounded),
                onTap: _isClearingCache ? null : _clearCache,
              ),
              const Divider(height: 1, indent: 56),
              ListTile(
                leading: Icon(Icons.delete_forever_rounded, color: colorScheme.error),
                title: Text(
                  'Clear All Data',
                  style: TextStyle(color: colorScheme.error),
                ),
                subtitle: const Text('Removes all app data (files untouched)'),
                trailing: Icon(
                  Icons.chevron_right_rounded,
                  color: colorScheme.error,
                ),
                onTap: _clearLibrary,
              ),
            ],
          ),

          // About section
          _SectionHeader(label: 'About', theme: theme),
          _SettingsCard(
            colorScheme: colorScheme,
            children: [
              ListTile(
                leading: Icon(Icons.info_outline_rounded, color: colorScheme.primary),
                title: const Text('Comica'),
                subtitle: const Text('Version 1.0.0 — Material 3'),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'v1.0',
                    style: TextStyle(
                      color: colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final ThemeData theme;
  const _SectionHeader({required this.label, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
      child: Text(
        label.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          letterSpacing: 1.5,
          fontWeight: FontWeight.w800,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final ColorScheme colorScheme;
  final List<Widget> children;
  const _SettingsCard({required this.colorScheme, required this.children});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(16),
      child: Column(children: children),
    );
  }
}
