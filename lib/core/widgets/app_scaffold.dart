import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Reusable desktop page scaffold providing a standard header bar
/// (title, subtitle, actions) and a padded or flexible content area.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const <Widget>[],
    required this.body,
    this.padding = const EdgeInsets.all(24),
    this.floatingActionButton,
    this.scrollable = false,
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final Widget body;
  final EdgeInsetsGeometry padding;
  final Widget? floatingActionButton;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    final Widget header = Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(color: AppColors.divider, width: 1),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  title,
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurface,
                  ),
                ),
                if (subtitle != null) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (actions.isNotEmpty) ...<Widget>[
            const SizedBox(width: 16),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: actions,
            ),
          ],
        ],
      ),
    );

    Widget content = Padding(
      padding: padding,
      child: body,
    );

    if (scrollable) {
      content = SingleChildScrollView(
        child: content,
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          header,
          Expanded(child: content),
        ],
      ),
      floatingActionButton: floatingActionButton,
    );
  }
}
