import 'package:donaciones/app/shell_scaffold.dart';
import 'package:donaciones/features/admin/presentation/admin_panel_screen.dart';
import 'package:donaciones/features/auth/presentation/login_screen.dart';
import 'package:donaciones/features/auth/presentation/register_screen.dart';
import 'package:donaciones/features/auth/presentation/reset_password_screen.dart';
import 'package:donaciones/features/donations/presentation/donation_tracking_screen.dart';
import 'package:donaciones/features/donations/presentation/donations_hub_screen.dart';
import 'package:donaciones/features/matching/presentation/matches_screen.dart';
import 'package:donaciones/features/profile/presentation/profile_screen.dart';
import 'package:donaciones/features/publications/presentation/create_publication_screen.dart';
import 'package:donaciones/features/publications/presentation/feed_screen.dart';
import 'package:donaciones/features/publications/presentation/publication_detail_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Shared GoRouter instance provider for DonaPlusApp.
final appRouterProvider = Provider<GoRouter>((ref) => createAppRouter());

/// Builds the declarative GoRouter configuration covering all MVP routes.
GoRouter createAppRouter({String initialLocation = '/'}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      ShellRoute(
        builder: (context, state, child) =>
            ShellScaffold(location: state.uri.path, child: child),
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const FeedScreen(),
          ),
          GoRoute(
            path: '/matches',
            builder: (context, state) => const MatchesScreen(),
          ),
          GoRoute(
            path: '/create',
            builder: (context, state) => const CreatePublicationScreen(),
          ),
          GoRoute(
            path: '/donations',
            builder: (context, state) => const DonationsHubScreen(),
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfileScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/reset-password',
        builder: (context, state) => const ResetPasswordScreen(),
      ),
      GoRoute(
        path: '/publications/:id',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return PublicationDetailScreen(
            key: ValueKey(id),
            publicationId: id,
          );
        },
      ),
      GoRoute(
        path: '/donations/:id',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return DonationTrackingScreen(
            key: ValueKey(id),
            donationId: id,
          );
        },
      ),
      GoRoute(
        path: '/admin',
        builder: (context, state) => const AdminPanelScreen(),
      ),
    ],
  );
}
