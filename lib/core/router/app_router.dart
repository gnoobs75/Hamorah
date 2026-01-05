import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/conversation/presentation/screens/conversation_screen.dart';
import '../../features/reader/presentation/screens/reader_screen.dart';
import '../../features/search/presentation/screens/search_screen.dart';
import '../../features/library/presentation/screens/library_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/onboarding/presentation/screens/onboarding_screen.dart';
import '../../features/loading/presentation/screens/loading_screen.dart';
import '../../features/pastors_notes/presentation/screens/sessions_list_screen.dart';
import '../../features/pastors_notes/presentation/screens/recording_screen.dart';
import '../../features/pastors_notes/presentation/screens/session_detail_screen.dart';
import '../../features/reading_plans/presentation/screens/reading_plans_screen.dart';
import '../../features/reading_plans/presentation/screens/plan_detail_screen.dart';
import '../../features/reading_plans/presentation/screens/daily_reading_screen.dart';
import '../../features/devotional/presentation/screens/devotional_screen.dart';
import '../../features/memorization/presentation/screens/memory_verses_screen.dart';
import '../../features/memorization/presentation/screens/practice_screen.dart';
import '../widgets/main_scaffold.dart';

/// Route names for type-safe navigation
class AppRoutes {
  static const String loading = '/';
  static const String onboarding = '/onboarding';
  static const String conversation = '/conversation';
  static const String reader = '/reader';
  static const String search = '/search';
  static const String library = '/library';
  static const String settings = '/settings';
  static const String pastorsNotes = '/pastors-notes';
  static const String pastorsNotesRecord = '/pastors-notes/record';
  static const String readingPlans = '/reading-plans';
  static const String devotional = '/devotional';
  static const String memorization = '/memorization';
}

/// App router configuration using go_router
class AppRouter {
  static final _rootNavigatorKey = GlobalKey<NavigatorState>();
  static final _shellNavigatorKey = GlobalKey<NavigatorState>();

  static GoRouter router() {
    return GoRouter(
      navigatorKey: _rootNavigatorKey,
      initialLocation: AppRoutes.loading,
      routes: [
        // Loading screen (initialization)
        GoRoute(
          path: AppRoutes.loading,
          builder: (context, state) => const LoadingScreen(),
        ),

        // Onboarding (outside main shell)
        GoRoute(
          path: AppRoutes.onboarding,
          builder: (context, state) => const OnboardingScreen(),
        ),

        // Main app shell with bottom navigation
        ShellRoute(
          navigatorKey: _shellNavigatorKey,
          builder: (context, state, child) {
            return MainScaffold(child: child);
          },
          routes: [
            GoRoute(
              path: AppRoutes.conversation,
              pageBuilder: (context, state) => const NoTransitionPage(
                child: ConversationScreen(),
              ),
            ),
            GoRoute(
              path: AppRoutes.reader,
              pageBuilder: (context, state) => const NoTransitionPage(
                child: ReaderScreen(),
              ),
            ),
            GoRoute(
              path: AppRoutes.search,
              pageBuilder: (context, state) => const NoTransitionPage(
                child: SearchScreen(),
              ),
            ),
            GoRoute(
              path: AppRoutes.library,
              pageBuilder: (context, state) => const NoTransitionPage(
                child: LibraryScreen(),
              ),
            ),
          ],
        ),

        // Settings (outside shell, full screen)
        GoRoute(
          path: AppRoutes.settings,
          builder: (context, state) => const SettingsScreen(),
        ),

        // Pastor's Notes feature
        GoRoute(
          path: AppRoutes.pastorsNotes,
          builder: (context, state) => const SessionsListScreen(),
          routes: [
            GoRoute(
              path: 'record',
              builder: (context, state) => const RecordingScreen(),
            ),
            GoRoute(
              path: ':sessionId',
              builder: (context, state) {
                final sessionId = state.pathParameters['sessionId']!;
                return SessionDetailScreen(sessionId: sessionId);
              },
            ),
          ],
        ),

        // Reading Plans feature
        GoRoute(
          path: AppRoutes.readingPlans,
          builder: (context, state) => const ReadingPlansScreen(),
          routes: [
            GoRoute(
              path: ':planId',
              builder: (context, state) {
                final planId = state.pathParameters['planId']!;
                return PlanDetailScreen(planId: planId);
              },
              routes: [
                GoRoute(
                  path: 'day/:dayNumber',
                  builder: (context, state) {
                    final planId = state.pathParameters['planId']!;
                    final dayNumber = int.tryParse(state.pathParameters['dayNumber'] ?? '1') ?? 1;
                    return DailyReadingScreen(planId: planId, dayNumber: dayNumber);
                  },
                ),
              ],
            ),
          ],
        ),

        // Daily Devotional feature
        GoRoute(
          path: AppRoutes.devotional,
          builder: (context, state) => const DevotionalScreen(),
        ),

        // Memorization feature
        GoRoute(
          path: AppRoutes.memorization,
          builder: (context, state) => const MemoryVersesScreen(),
          routes: [
            GoRoute(
              path: 'practice',
              builder: (context, state) => const PracticeScreen(),
            ),
          ],
        ),
      ],
    );
  }
}
