import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/onboarding/onboarding_screen.dart';
import '../../features/library/library_screen.dart';
import '../../features/reader/reader_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/onboarding',
    routes: [
      GoRoute(
        path: '/onboarding',
        name: 'onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/library',
        name: 'library',
        builder: (context, state) => const LibraryScreen(),
      ),
      GoRoute(
        path: '/reader/:id',
        name: 'reader',
        builder: (context, state) {
          final comicId = state.pathParameters['id']!;
          final startPage =
              int.tryParse(state.uri.queryParameters['page'] ?? '1') ?? 1;
          return ReaderScreen(comicId: comicId, startPage: startPage);
        },
      ),
    ],
  );
});
