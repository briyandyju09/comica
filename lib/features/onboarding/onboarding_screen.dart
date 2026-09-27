import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';

import '../library/library_provider.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen>
    with TickerProviderStateMixin {
  late final AnimationController _heroCtrl;
  late final AnimationController _contentCtrl;
  late final Animation<double> _iconScale;
  late final Animation<double> _contentFade;
  late final Animation<Offset> _contentSlide;

  bool _picking = false;

  @override
  void initState() {
    super.initState();

    _heroCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _contentCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));

    _iconScale = CurvedAnimation(parent: _heroCtrl, curve: Curves.elasticOut);
    _contentFade = CurvedAnimation(parent: _contentCtrl, curve: Curves.easeOut);
    _contentSlide = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _contentCtrl, curve: Curves.easeOutCubic));

    // Check if root is already set
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final state = ref.read(libraryProvider);
      if (state.rootPath != null) {
        context.goNamed('library');
        return;
      }
      _heroCtrl.forward();
      await Future.delayed(const Duration(milliseconds: 300));
      _contentCtrl.forward();
    });
  }

  @override
  void dispose() {
    _heroCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFolder() async {
    HapticFeedback.mediumImpact();
    setState(() => _picking = true);

    try {
      final result = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Select your comics folder',
      );

      if (result != null && mounted) {
        await ref.read(libraryProvider.notifier).setRootPath(result);
        if (mounted) context.goNamed('library');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open folder: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      body: Stack(
        children: [
          // Background gradient
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    scheme.primaryContainer.withOpacity(0.6),
                    scheme.surface,
                  ],
                  stops: const [0.0, 0.55],
                ),
              ),
            ),
          ),

          // Decorative circles
          Positioned(
            top: -80,
            right: -60,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scheme.primary.withOpacity(0.08),
              ),
            ),
          ),
          Positioned(
            top: 60,
            left: -40,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scheme.tertiary.withOpacity(0.07),
              ),
            ),
          ),

          // Main content
          SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 2),

                // Hero icon
                ScaleTransition(
                  scale: _iconScale,
                  child: Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: scheme.primary,
                      boxShadow: [
                        BoxShadow(
                          color: scheme.primary.withOpacity(0.35),
                          blurRadius: 40,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Icon(Icons.auto_stories_rounded,
                        size: 70, color: scheme.onPrimary),
                  ),
                ),

                const Spacer(flex: 1),

                // Content
                FadeTransition(
                  opacity: _contentFade,
                  child: SlideTransition(
                    position: _contentSlide,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            'Comica',
                            style: tt.displaySmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: scheme.primary,
                              letterSpacing: -1,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Your personal comic library,\nbeautifully organized.',
                            style: tt.titleMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                              height: 1.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 40),

                          // Feature pills
                          _FeatureRow(scheme: scheme),

                          const SizedBox(height: 44),

                          // Pick folder button
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: _picking ? null : _pickFolder,
                              icon: _picking
                                  ? SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: scheme.onPrimary,
                                      ),
                                    )
                                  : const Icon(Icons.folder_open_rounded),
                              label: Text(
                                  _picking ? 'Opening…' : 'Choose Comics Folder'),
                              style: FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(56),
                                textStyle: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'Supports PDF comics sorted by (001) numbering',
                            style: tt.bodySmall
                                ?.copyWith(color: scheme.onSurfaceVariant),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const Spacer(flex: 3),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final ColorScheme scheme;
  const _FeatureRow({required this.scheme});

  @override
  Widget build(BuildContext context) {
    final features = [
      (Icons.sort_rounded, 'Smart Sort'),
      (Icons.menu_book_rounded, 'PDF Reader'),
      (Icons.bookmark_rounded, 'Bookmarks'),
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: features
          .map((f) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: _FeaturePill(icon: f.$1, label: f.$2, scheme: scheme),
              ))
          .toList(),
    );
  }
}

class _FeaturePill extends StatelessWidget {
  final IconData icon;
  final String label;
  final ColorScheme scheme;
  const _FeaturePill(
      {required this.icon, required this.label, required this.scheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: scheme.onSecondaryContainer),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: scheme.onSecondaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}
