import 'package:go_router/go_router.dart';
import 'package:orinx/features/auth/screens/auth_callback_page.dart'
    show AuthCallbackPage;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/signup_screen.dart';
import '../../features/auth/screens/forgot_password_screen.dart';
import '../../features/auth/screens/join_team_screen.dart';
import '../../features/auth/screens/set_password_screen.dart';
import '../../features/dashboard/screens/app_shell.dart';
import '../../features/settings/screens/settings_screen.dart';
import '../../features/settings/screens/plans_pricing_screen.dart';
import '../../features/settings/screens/get_app_screen.dart';
import '../../features/dashboard/screens/overview_screen.dart';
import '../../features/dashboard/screens/content_hub_screen.dart';
import '../../features/dashboard/screens/live_alerts_screen.dart';
import '../../features/dashboard/screens/keyword_monitoring_screen.dart';
import '../../features/settings/screens/help/privacy_policy_screen.dart';
import '../../features/settings/screens/help/contact_us_screen.dart';
import '../../features/settings/screens/help/suggest_improvements_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  redirect: (context, state) {
    final session = Supabase.instance.client.auth.currentSession;
    final location = state.matchedLocation;
    final fullUri = state.uri;

    String? sanitizeNext(String? next) {
      if (next == null) return null;
      final trimmed = next.trim();
      if (trimmed.isEmpty) return null;
      if (trimmed.startsWith('/')) return trimmed;
      if (trimmed.startsWith('#/')) return trimmed.substring(1);
      if (trimmed.startsWith('/#/')) return trimmed.substring(2);
      return null;
    }

    String loginWithNext(Uri nextUri) {
      return '/login?next=${Uri.encodeComponent(nextUri.toString())}';
    }

    // Public routes that don't require auth
    final isPublicRoute =
        location == '/' ||
        location == '/login' ||
        location == '/signup' ||
        location == '/forgot-password' ||
        location == '/auth/callback' ||
        location == '/join-team' ||
        location == '/set-password';

    // Invite onboarding must never be wrapped into /login by the router guard.
    if (location.contains('set-password') ||
        location.contains('join-team') ||
        location.contains('auth/callback')) {
      return null;
    }

    if (session == null) {
      // If not logged in and trying to access protected route (like /app/*)
      if (!isPublicRoute && location.startsWith('/app')) {
        return loginWithNext(fullUri);
      }
    } else {
      // If logged in

      // Prevent infinite redirect loops if already on target pages
      if (location == '/app/overview' || location == '/set-password') {
        return null;
      }

      // If user is on login/signup pages, push them into app
      if (location == '/login' ||
          location == '/signup' ||
          location == '/forgot-password') {
        final next = sanitizeNext(fullUri.queryParameters['next']);
        return next ?? '/app/overview';
      }

      // If root /app is hit, redirect to overview
      if (location == '/app') {
        return '/app/overview';
      }
    }
    return null;
  },
  routes: [
    GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
    GoRoute(
      path: '/login',
      builder: (context, state) {
        final next = state.uri.queryParameters['next'];
        return LoginScreen(next: next);
      },
    ),
    GoRoute(
      path: '/signup',
      builder: (context, state) {
        final next = state.uri.queryParameters['next'];
        return SignupScreen(next: next);
      },
    ),
    GoRoute(
      path: '/forgot-password',
      builder: (context, state) => const ForgotPasswordScreen(),
    ),
    GoRoute(
      path: '/set-password',
      builder: (context, state) {
        final next = state.uri.queryParameters['next'];
        return SetPasswordScreen(next: next);
      },
    ),
    GoRoute(
      path: '/auth/callback',
      builder: (context, state) => const AuthCallbackPage(),
    ),
    GoRoute(
      path: '/join-team',
      builder: (context, state) {
        final token = state.uri.queryParameters['token'];
        return JoinTeamScreen(token: token);
      },
    ),
    ShellRoute(
      builder: (context, state, child) => AppShell(child: child),
      routes: [
        GoRoute(
          path: '/app/overview',
          builder: (context, state) => const OverviewScreen(),
        ),
        GoRoute(
          path: '/app/content',
          builder: (context, state) => const ContentHubScreen(),
        ),
        GoRoute(
          path: '/app/alerts',
          builder: (context, state) => const LiveAlertsScreen(),
        ),
        GoRoute(
          path: '/app/keywords',
          builder: (context, state) => const KeywordMonitoringScreen(),
        ),
        GoRoute(
          path: '/app/settings',
          redirect: (context, state) => '/app/settings/profile',
        ),
        GoRoute(
          path: '/app/settings/:tab',
          builder: (context, state) {
            final tab = state.pathParameters['tab'] ?? 'profile';
            return SettingsScreen(initialTab: tab);
          },
        ),
        GoRoute(
          path: '/app/settings/pricing',
          builder: (context, state) => const PlansPricingScreen(),
        ),
        GoRoute(
          path: '/app/settings/get-app',
          builder: (context, state) => const GetAppScreen(),
        ),
        GoRoute(
          path: '/app/settings/privacy-policy',
          builder: (context, state) => const PrivacyPolicyScreen(),
        ),
        GoRoute(
          path: '/app/settings/contact-us',
          builder: (context, state) => const ContactUsScreen(),
        ),
        GoRoute(
          path: '/app/settings/suggest-improvements',
          builder: (context, state) => const SuggestImprovementsScreen(),
        ),
      ],
    ),
  ],
);