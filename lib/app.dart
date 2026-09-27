import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

class ComicaApp extends ConsumerWidget {
  const ComicaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return DynamicColorBuilder(
      builder: (lightScheme, darkScheme) {
        return MaterialApp.router(
          title: 'Comica',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(dynamicScheme: lightScheme),
          darkTheme: AppTheme.dark(dynamicScheme: darkScheme),
          themeMode: ThemeMode.system,
          routerConfig: router,
        );
      },
    );
  }
}
