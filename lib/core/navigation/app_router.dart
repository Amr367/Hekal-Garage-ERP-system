import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/customers/customers_page.dart';
import '../../features/dashboard/dashboard_page.dart';
import '../../features/dev/print_test_page.dart';
import '../../features/inventory/inventory_page.dart';
import '../../features/invoices/invoices_page.dart';
import '../../features/purchases/purchases_page.dart';
import '../../features/reports/reports_page.dart';
import '../../features/settings/settings_page.dart';
import '../../features/stock_count/stock_count_page.dart';
import '../../features/work_orders/work_orders_page.dart';
import 'app_shell.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final GlobalKey<NavigatorState> _shellNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'shell');

/// Main application router configuring all top-level destinations
/// within the desktop [AppShell].
final GoRouter appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/dashboard',
  routes: <RouteBase>[
    // Redirect root to dashboard
    GoRoute(
      path: '/',
      redirect: (_, _) => '/dashboard',
    ),

    // Shell Route hosting all navigation destinations
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (BuildContext context, GoRouterState state, Widget child) {
        return AppShell(child: child);
      },
      routes: <RouteBase>[
        GoRoute(
          path: '/dashboard',
          pageBuilder: (BuildContext context, GoRouterState state) => const NoTransitionPage<void>(
            child: DashboardPage(),
          ),
        ),
        GoRoute(
          path: '/work-orders',
          pageBuilder: (BuildContext context, GoRouterState state) => const NoTransitionPage<void>(
            child: WorkOrdersPage(),
          ),
        ),
        GoRoute(
          path: '/invoices',
          pageBuilder: (BuildContext context, GoRouterState state) => const NoTransitionPage<void>(
            child: InvoicesPage(),
          ),
        ),
        GoRoute(
          path: '/customers',
          pageBuilder: (BuildContext context, GoRouterState state) => const NoTransitionPage<void>(
            child: CustomersPage(),
          ),
        ),
        GoRoute(
          path: '/inventory',
          pageBuilder: (BuildContext context, GoRouterState state) => const NoTransitionPage<void>(
            child: InventoryPage(),
          ),
        ),
        GoRoute(
          path: '/purchases',
          pageBuilder: (BuildContext context, GoRouterState state) => const NoTransitionPage<void>(
            child: PurchasesPage(),
          ),
        ),
        GoRoute(
          path: '/stock-count',
          pageBuilder: (BuildContext context, GoRouterState state) => const NoTransitionPage<void>(
            child: StockCountPage(),
          ),
        ),
        GoRoute(
          path: '/reports',
          pageBuilder: (BuildContext context, GoRouterState state) => const NoTransitionPage<void>(
            child: ReportsPage(),
          ),
        ),
        GoRoute(
          path: '/settings',
          pageBuilder: (BuildContext context, GoRouterState state) => const NoTransitionPage<void>(
            child: SettingsPage(),
          ),
        ),
        GoRoute(
          path: '/dev/print-test',
          pageBuilder: (BuildContext context, GoRouterState state) => const NoTransitionPage<void>(
            child: PrintTestPage(),
          ),
        ),
      ],
    ),
  ],
);
