import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mtc_app/features/notifications/presentation/providers/push_providers.dart';

import 'router/app_router.dart';
import 'theme/app_theme.dart';
import 'theme/theme_mode_controller.dart';

class MtcApp extends ConsumerWidget {
  const MtcApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeControllerProvider);
    // Keeps this device's FCM token registered/fresh for as long as the app
    // is alive — see `push_providers.dart`. Nothing in this build method
    // reads its (void) value; watching it here only pins its lifetime to
    // the app's, same as `routerProvider`/`themeModeControllerProvider`.
    ref.watch(pushRegistrationProvider);

    return MaterialApp.router(
      title: 'MTC - Mali Trade Connect',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
