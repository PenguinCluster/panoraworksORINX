import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/signup_screen.dart';
import '../../features/auth/screens/forgot_password_screen.dart';
import '../../features/auth/screens/join_team_screen.dart';
import '../../features/dashboard/screens/app_shell.dart';
import '../../features/dashboard/screens/placeholder_screen.dart';
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
    final isLoggingIn =
        state.matchedLocation == '/login' ||
        state.matchedLocation == '/signup' ||
        state.matchedLocation == '/forgot-password';

    if (session == null) {
      if (state.matchedLocation.startsWith('/app')) {
        return '/login';
      }
    } else {
      if (isLoggingIn) {
        return '/app/overview';
      }
      if (state.matchedLocation == '/app') {
        return '/app/overview';
      }
    }
    return null;
  },
  routes: [
    GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    GoRoute(path: '/signup', builder: (context, state) => const SignupScreen()),
    GoRoute(
      path: '/forgot-password',
      builder: (context, state) => const ForgotPasswordScreen(),
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
