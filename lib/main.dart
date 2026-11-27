import 'dart:async';
import 'dart:convert';

import 'package:donaciones/app/router.dart';
import 'package:donaciones/app/theme.dart';
import 'package:donaciones/core/auth/password_recovery.dart';
import 'package:donaciones/core/auth/registration_auth_options.dart';
import 'package:donaciones/core/location/android_device_location.dart';
import 'package:donaciones/core/mock/mock_tenant_store.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase/supabase.dart';

const _komunaProjectUrl = 'https://iqaroikyejukgbvoomju.supabase.co';
const _komunaPublishableKey = 'sb_publishable__wnAojw95na50xjH0ZlAJQ_W2EACqDO';

Future<void> main() async {
  const configuredUrl = String.fromEnvironment('SUPABASE_URL');
  const configuredKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
  const hasProjectOverride = configuredUrl != '' || configuredKey != '';
  final isAndroid = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  final url = hasProjectOverride ? configuredUrl : _komunaProjectUrl;
  final key = hasProjectOverride ? configuredKey : _komunaPublishableKey;
  WidgetsFlutterBinding.ensureInitialized();
  final uri = Uri.tryParse(url);
  if (key.isEmpty || uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
    throw StateError('Configura SUPABASE_URL y SUPABASE_PUBLISHABLE_KEY.');
  }
  final client = SupabaseClient(
    url,
    key,
    authOptions: registrationAuthOptions(),
  );
  if (isAndroid) {
    await _restoreAndroidSession(client);
  }
  runApp(
    ProviderScope(
      overrides: [
        if (isAndroid)
          passwordRecoveryProvider.overrideWithValue(
            PasswordRecovery(url: url, key: key),
          ),
        mockTenantStoreProvider.overrideWith(
          (ref) => OnlineTenantStore(
            client,
            locationLookup: isAndroid ? lookupAndroidApproximateLocation : null,
            emailConfirmationUrl: isAndroid
                ? androidEmailConfirmationUrl
                : null,
          ),
        ),
      ],
      child: const DonaPlusApp(),
    ),
  );
}

Future<void> _restoreAndroidSession(SupabaseClient client) async {
  const channel = MethodChannel('donaplus/session');
  try {
    final session = await channel.invokeMethod<String>('read');
    if (session != null) {
      await client.auth
          .recoverSession(session)
          .timeout(const Duration(seconds: 8));
    }
  } on Exception {
    // A disconnected device can still open the app and sign in when it reconnects.
  }
  client.auth.onAuthStateChange.listen((event) async {
    if (event.session == null && event.event != AuthChangeEvent.signedOut) {
      return;
    }
    try {
      await channel.invokeMethod<void>(
        'save',
        event.session == null ? null : jsonEncode(event.session!.toJson()),
      );
    } on PlatformException {
      // Authentication can continue for the current process.
    }
  }, onError: (Object _) {});
}

/// Root Komuna application widget applying live accessibility and routing.
class DonaPlusApp extends ConsumerWidget {
  const DonaPlusApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accessibility = ref.watch(accessibilityProvider);
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Komuna',
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
