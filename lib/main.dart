import 'package:donaciones/app/router.dart';
import 'package:donaciones/app/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  runApp(const ProviderScope(child: DonaPlusApp()));
}

/// Root DonaPlus application widget applying live accessibility and routing.
class DonaPlusApp extends ConsumerWidget {
  const DonaPlusApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accessibility = ref.watch(accessibilityProvider);
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'DonaPlus',
      debugShowCheckedModeBanner: false,
      theme: buildDonaPlusTheme(
        highContrast: accessibility.highContrast,
        reduceMotion: accessibility.reduceMotion,
      ),
      routerConfig: router,
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        return MediaQuery(
          data: mediaQuery.copyWith(
            textScaler: TextScaler.linear(accessibility.textScaleFactor),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
