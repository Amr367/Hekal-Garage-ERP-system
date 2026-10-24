import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../strings.dart';
import '../theme/app_colors.dart';
import 'nav_destination.dart';

/// Desktop RTL Shell managing sidebar navigation, top-level layout,
/// and global keyboard shortcuts.
class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.child,
  });

  final Widget child;

  int _calculateSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).uri.path;
    final int index = AppNavDestination.all.indexWhere(
      (dest) => location == dest.route || location.startsWith('${dest.route}/'),
    );
    return index >= 0 ? index : 0;
  }

  void _onDestinationSelected(BuildContext context, int index) {
    if (index >= 0 && index < AppNavDestination.all.length) {
      final dest = AppNavDestination.all[index];
      context.go(dest.route);
    }
  }

  @override
  Widget build(BuildContext context) {
    final int selectedIndex = _calculateSelectedIndex(context);

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        // Ctrl+P -> Navigate to Print Test
        const SingleActivator(LogicalKeyboardKey.keyP, control: true): () {
          context.go('/dev/print-test');
        },
        // Ctrl+1..9 -> Quick navigate to tabs
        const SingleActivator(LogicalKeyboardKey.digit1, control: true): () =>
            _onDestinationSelected(context, 0),
        const SingleActivator(LogicalKeyboardKey.digit2, control: true): () =>
            _onDestinationSelected(context, 1),
        const SingleActivator(LogicalKeyboardKey.digit3, control: true): () =>
            _onDestinationSelected(context, 2),
        const SingleActivator(LogicalKeyboardKey.digit4, control: true): () =>
            _onDestinationSelected(context, 3),
        const SingleActivator(LogicalKeyboardKey.digit5, control: true): () =>
            _onDestinationSelected(context, 4),
        const SingleActivator(LogicalKeyboardKey.digit6, control: true): () =>
            _onDestinationSelected(context, 5),
        const SingleActivator(LogicalKeyboardKey.digit7, control: true): () =>
            _onDestinationSelected(context, 6),
        const SingleActivator(LogicalKeyboardKey.digit8, control: true): () =>
            _onDestinationSelected(context, 7),
        const SingleActivator(LogicalKeyboardKey.digit9, control: true): () =>
            _onDestinationSelected(context, 8),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: AppColors.background,
          body: Row(
            children: <Widget>[
              // ── Right-Side Sidebar in RTL ─────────────────────────────────
              Container(
                width: 250,
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  border: Border(
                    left: BorderSide(color: AppColors.divider, width: 1),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    // ── Header / Logo ───────────────────────────────────────
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: AppColors.divider, width: 1),
                        ),
                      ),
                      child: Row(
                        children: <Widget>[
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.directions_car, color: Colors.white, size: 24),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Text(
                                  AppStrings.appTitle,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.onSurface,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'مركز الصيانة والمخزن',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.onSurfaceVariant,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ── Scrollable Nav Items (Prevents overflow at 150% scaling) ──
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        itemCount: AppNavDestination.all.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 4),
                        itemBuilder: (BuildContext ctx, int index) {
                          final AppNavDestination dest = AppNavDestination.all[index];
                          final bool isSelected = index == selectedIndex;

                          return Material(
                            color: isSelected ? AppColors.primaryContainer : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            child: InkWell(
                              onTap: () => _onDestinationSelected(context, index),
                              borderRadius: BorderRadius.circular(8),
                              hoverColor: AppColors.primaryContainer.withValues(alpha: 0.4),
                              child: Container(
                                height: 46,
                                padding: const EdgeInsets.symmetric(horizontal: 14),
                                child: Row(
                                  children: <Widget>[
                                    Icon(
                                      isSelected ? dest.selectedIcon : dest.icon,
                                      size: 22,
                                      color: isSelected
                                          ? AppColors.primary
                                          : AppColors.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        dest.label,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight:
                                              isSelected ? FontWeight.w700 : FontWeight.w500,
                                          color: isSelected
                                              ? AppColors.primary
                                              : AppColors.onSurface,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    // ── Footer / Status ─────────────────────────────────────
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: const BoxDecoration(
                        border: Border(
                          top: BorderSide(color: AppColors.divider, width: 1),
                        ),
                      ),
                      child: Row(
                        children: <Widget>[
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.success,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              AppStrings.appVersion,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.onSurfaceVariant,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── Main Page Content ─────────────────────────────────────────
              Expanded(
                child: child,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
