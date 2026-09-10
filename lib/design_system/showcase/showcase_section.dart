import 'package:flutter/material.dart';

/// One example on a showcase page.
///
/// The builder returns the **production** widget, wrapped in nothing but
/// sizing. That is the whole discipline of this directory: a showcase that
/// builds its own version of a component documents a component nobody ships.
@immutable
class ShowcaseExample {
  const ShowcaseExample({
    required this.name,
    required this.builder,
    this.description,
  });

  final String name;

  /// Where the *rule* is written. The reasoning that would otherwise be buried
  /// in a doc comment belongs on screen, next to the thing it explains.
  final String? description;

  final WidgetBuilder builder;
}

/// One page of the showcase.
@immutable
class ShowcaseSection {
  const ShowcaseSection({
    required this.title,
    required this.icon,
    required this.examples,
    this.description,
  });

  final String title;
  final IconData icon;
  final String? description;
  final List<ShowcaseExample> examples;
}
