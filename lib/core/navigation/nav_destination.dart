import 'package:flutter/material.dart';
import '../strings.dart';

/// Navigation item description for the sidebar rail.
class AppNavDestination {
  const AppNavDestination({
    required this.label,
    required this.route,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final String route;
  final IconData icon;
  final IconData selectedIcon;

  static const List<AppNavDestination> all = <AppNavDestination>[
    AppNavDestination(
      label: AppStrings.navDashboard,
      route: '/dashboard',
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard,
    ),
    AppNavDestination(
      label: AppStrings.navWorkOrders,
      route: '/work-orders',
      icon: Icons.build_outlined,
      selectedIcon: Icons.build,
    ),
    AppNavDestination(
      label: AppStrings.navInvoices,
      route: '/invoices',
      icon: Icons.receipt_long_outlined,
      selectedIcon: Icons.receipt_long,
    ),
    AppNavDestination(
      label: AppStrings.navCustomers,
      route: '/customers',
      icon: Icons.people_alt_outlined,
      selectedIcon: Icons.people_alt,
    ),
    AppNavDestination(
      label: AppStrings.navInventory,
      route: '/inventory',
      icon: Icons.inventory_2_outlined,
      selectedIcon: Icons.inventory_2,
    ),
    AppNavDestination(
      label: AppStrings.navPurchases,
      route: '/purchases',
      icon: Icons.shopping_cart_outlined,
      selectedIcon: Icons.shopping_cart,
    ),
    AppNavDestination(
      label: AppStrings.navStockCount,
      route: '/stock-count',
      icon: Icons.fact_check_outlined,
      selectedIcon: Icons.fact_check,
    ),
    AppNavDestination(
      label: AppStrings.navExpenses,
      route: '/expenses',
      icon: Icons.payments_outlined,
      selectedIcon: Icons.payments,
    ),
    AppNavDestination(
      label: AppStrings.navEmployees,
      route: '/employees',
      icon: Icons.badge_outlined,
      selectedIcon: Icons.badge,
    ),
    AppNavDestination(
      label: AppStrings.navReports,
      route: '/reports',
      icon: Icons.bar_chart_outlined,
      selectedIcon: Icons.bar_chart,
    ),
    AppNavDestination(
      label: AppStrings.navSettings,
      route: '/settings',
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings,
    ),
  ];
}
