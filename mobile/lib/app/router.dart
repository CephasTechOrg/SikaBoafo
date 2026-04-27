import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../shared/providers/core_providers.dart';
import '../features/auth/presentation/auth_shell_screen.dart';
import '../features/auth/presentation/set_pin_screen.dart';
import '../features/dashboard/presentation/dashboard_shell_screen.dart';
import '../features/dashboard/presentation/reports_screen.dart';
import '../features/onboarding/presentation/business_onboarding_screen.dart';
import '../features/onboarding/presentation/splash_screen.dart';
import '../features/customers/presentation/customer_detail_screen.dart';
import '../features/customers/presentation/customers_screen.dart';
import '../features/debts/presentation/debt_detail_screen.dart';
import '../features/debts/presentation/debts_screen.dart';
import '../features/debts/presentation/receive_repayment_screen.dart';
import '../features/settings/presentation/connect_paystack_screen.dart';
import '../features/settings/presentation/business_profile_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/settings/presentation/staff_screen.dart';

enum AppRoute {
  splash('/'),
  auth('/auth'),
  onboarding('/onboarding'),
  setPin('/set-pin'),
  home('/home'),
  debts('/debts'),
  reports('/reports'),
  settings('/settings'),
  businessProfile('/settings/business-profile'),
  staff('/settings/staff'),
  paystack('/settings/payments/paystack'),
  customers('/customers'),
  customerDetail('/customers/:id'),
  debtDetail('/debts/:id'),
  receiveRepayment('/debts/:id/repayment');

  const AppRoute(this.path);
  final String path;
}

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

const _returnToKey = 'returnTo';

String? sanitizeReturnTo(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty || !trimmed.startsWith('/')) {
    return null;
  }
  return trimmed;
}

String buildRouteLocation(AppRoute route, {String? returnTo}) {
  final sanitized = sanitizeReturnTo(returnTo);
  if (sanitized == null) {
    return route.path;
  }
  return Uri(
    path: route.path,
    queryParameters: <String, String>{_returnToKey: sanitized},
  ).toString();
}

String resolveReturnToOrHome(String? returnTo) {
  return sanitizeReturnTo(returnTo) ?? AppRoute.home.path;
}

bool _isProtectedPath(String path) {
  return path == AppRoute.home.path ||
      path == AppRoute.debts.path ||
      path.startsWith('${AppRoute.debts.path}/') ||
      path == AppRoute.reports.path ||
      path == AppRoute.settings.path ||
      path.startsWith('${AppRoute.settings.path}/') ||
      path == AppRoute.customers.path ||
      path.startsWith('${AppRoute.customers.path}/');
}

Future<String?> _redirectGuard(Ref ref, GoRouterState state) async {
  if (!_isProtectedPath(state.uri.path)) {
    return null;
  }

  final storage = ref.read(secureTokenStorageProvider);
  final hasSession = await storage.hasPersistedSession();
  final gateComplete = await storage.hasCompletedSessionGate();
  if (hasSession && gateComplete) {
    return null;
  }

  return buildRouteLocation(
    AppRoute.splash,
    returnTo: state.uri.toString(),
  );
}

GoRouter createAppRouter(Ref ref) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: AppRoute.splash.path,
    redirect: (context, state) => _redirectGuard(ref, state),
    routes: [
      GoRoute(
        path: AppRoute.splash.path,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoute.auth.path,
        builder: (context, state) => const AuthShellScreen(),
      ),
      GoRoute(
        path: AppRoute.onboarding.path,
        builder: (context, state) => const BusinessOnboardingScreen(),
      ),
      GoRoute(
        path: AppRoute.setPin.path,
        builder: (context, state) => const SetPinScreen(),
      ),
      GoRoute(
        path: AppRoute.home.path,
        builder: (context, state) => const DashboardShellScreen(),
      ),
      GoRoute(
        path: AppRoute.debts.path,
        builder: (context, state) => const DebtsScreen(),
      ),
      GoRoute(
        path: AppRoute.reports.path,
        builder: (context, state) => const ReportsScreen(),
      ),
      GoRoute(
        path: AppRoute.settings.path,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: AppRoute.businessProfile.path,
        builder: (context, state) => const BusinessProfileScreen(),
      ),
      GoRoute(
        path: AppRoute.staff.path,
        builder: (context, state) => const StaffScreen(),
      ),
      GoRoute(
        path: AppRoute.paystack.path,
        builder: (context, state) => const ConnectPaystackScreen(),
      ),
      GoRoute(
        path: AppRoute.customers.path,
        builder: (context, state) => const CustomersScreen(),
      ),
      GoRoute(
        path: AppRoute.customerDetail.path,
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return CustomerDetailScreen(customerId: id);
        },
      ),
      GoRoute(
        path: AppRoute.debtDetail.path,
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return DebtDetailScreen(receivableId: id);
        },
        routes: [
          GoRoute(
            path: 'repayment',
            builder: (context, state) {
              final id = state.pathParameters['id'] ?? '';
              return ReceiveRepaymentScreen(receivableId: id);
            },
          ),
        ],
      ),
    ],
  );
}
