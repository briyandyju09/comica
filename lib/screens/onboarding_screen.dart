import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/library_provider.dart';
import 'library_screen.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen>
    with TickerProviderStateMixin {
  late AnimationController _entryController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;
  bool _isPickingFolder = false;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnim = CurvedAnimation(parent: _entryController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entryController, curve: Curves.easeOut));
    _entryController.forward();
  }

  @override
  void dispose() {
    _entryController.dispose();
    super.dispose();
  }

  Future<void> _pickFolder() async {
    HapticFeedback.lightImpact();
    setState(() => _isPickingFolder = true);

    try {
      final result = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Select your comics folder',
      );

      if (result != null && mounted) {
        await ref.read(appSettingsProvider.notifier).setRootDirectory(result);
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const LibraryScreen()),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isPickingFolder = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          // Background gradient
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.3, -0.5),
                  radius: 1.2,
                  colors: [
                    colorScheme.primary.withOpacity(0.25),
                    colorScheme.surface,
                  ],
                ),
              ),
            ),
          ),

          // Decorative circles
          Positioned(
            top: -80,
            right: -80,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colorScheme.primary.withOpacity(0.08),
              ),
            ),
          ),
          Positioned(
            bottom: size.height * 0.3,
            left: -60,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colorScheme.secondary.withOpacity(0.1),
              ),
            ),
          ),

          // Content
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Spacer(flex: 2),

                      // App icon / logo
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(22),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              colorScheme.primary,
                              colorScheme.secondary,
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: colorScheme.primary.withOpacity(0.4),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.auto_stories_rounded,
                          color: colorScheme.onPrimary,
                          size: 44,
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Title
                      Text(
                        'Comica',
                        style: theme.textTheme.displaySmall?.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Your comics. Beautifully read.',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),

                      const SizedBox(height: 48),

                      // Feature points
                      ..._features(colorScheme, theme),

                      const Spacer(flex: 3),

                      // CTA button
                      FilledButton.icon(
                        onPressed: _isPickingFolder ? null : _pickFolder,
                        icon: _isPickingFolder
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: colorScheme.onPrimary,
                                ),
                              )
                            : const Icon(Icons.folder_open_rounded),
                        label: Text(
                          _isPickingFolder
                              ? 'Opening...'
                              : 'Choose Comics Folder',
                        ),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          textStyle: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Center(
                        child: Text(
                          'CBZ, CBR & PDF files supported',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),

                      const Spacer(flex: 1),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _features(ColorScheme colorScheme, ThemeData theme) {
    final items = [
      (_FeatureData(
        icon: Icons.sort_rounded,
        title: 'Smart Sorting',
        subtitle: 'Auto-sorts by (001) numbering',
      )),
      (_FeatureData(
        icon: Icons.bookmark_rounded,
        title: 'Reading Memory',
        subtitle: 'Picks up right where you left off',
      )),
      (_FeatureData(
        icon: Icons.fast_forward_rounded,
        title: 'Auto Progression',
        subtitle: 'Flows seamlessly to next issue',
      )),
    ];

    return items
        .map(
          (f) => Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(f.icon,
                      color: colorScheme.onPrimaryContainer, size: 22),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(f.title, style: theme.textTheme.titleMedium),
                      Text(f.subtitle,
                          style: theme.textTheme.bodyMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
          ),
        )
        .toList();
  }
}

class _FeatureData {
  final IconData icon;
  final String title;
  final String subtitle;
  const _FeatureData({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
}
