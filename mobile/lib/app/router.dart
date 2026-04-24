import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/presentation/auth_shell_screen.dart';
import '../features/auth/presentation/set_pin_screen.dart';
import '../features/dashboard/presentation/dashboard_shell_screen.dart';
import '../features/onboarding/presentation/business_onboarding_screen.dart';
import '../features/onboarding/presentation/splash_screen.dart';
import '../features/customers/presentation/customer_detail_screen.dart';
import '../features/customers/presentation/customers_screen.dart';
import '../features/settings/presentation/connect_paystack_screen.dart';
import '../features/settings/presentation/staff_screen.dart';

enum AppRoute {
  splash('/'),
  auth('/auth'),
  onboarding('/onboarding'),
  setPin('/set-pin'),
  home('/home'),
  staff('/staff'),
  paystack('/settings/payments/paystack'),
  customers('/customers'),
  customerDetail('/customers/:id');

  const AppRoute(this.path);
  final String path;
}

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

GoRouter createAppRouter() {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: AppRoute.splash.path,
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
    ],
  );
}
