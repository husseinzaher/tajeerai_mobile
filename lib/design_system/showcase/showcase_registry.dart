import 'sections/authentication_section.dart';
import 'sections/components_section.dart';
import 'sections/foundations_section.dart';
import 'sections/shell_section.dart';
import 'showcase_section.dart';

/// Every section, in the order they appear.
///
/// The smoke test reads this list, so a section added here is pumped in every
/// theme, direction and text scale without anybody adding a test case.
List<ShowcaseSection> showcaseSections() => <ShowcaseSection>[
  foundationsSection(),
  buttonsSection(),
  formsSection(),
  displaySection(),
  statesSection(),
  overlaysSection(),
  authenticationSection(),
  shellSection(),
];
