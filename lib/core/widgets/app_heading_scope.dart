import 'package:flutter/material.dart';

/// Declares the screen title already presented by the surrounding app bar.
/// Pushed routes outside this body keep their own headings.
class AppHeadingScope extends InheritedWidget {
  const AppHeadingScope({
    super.key,
    required this.screen,
    required super.child,
  });
  final String screen;
  static bool owns(BuildContext context, Set<String> screens) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppHeadingScope>();
    return scope != null &&
        screens.any(
          (s) => s.trim().toLowerCase() == scope.screen.trim().toLowerCase(),
        );
  }

  @override
  bool updateShouldNotify(AppHeadingScope oldWidget) =>
      oldWidget.screen != screen;
}

class AppPageHeading extends StatelessWidget {
  const AppPageHeading({
    super.key,
    required this.title,
    required this.screens,
    this.spacing = 12,
  });
  final String title;
  final Set<String> screens;
  final double spacing;
  @override
  Widget build(BuildContext context) => AppHeadingScope.owns(context, screens)
      ? const SizedBox.shrink()
      : Padding(
          padding: EdgeInsets.only(bottom: spacing),
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        );
}
