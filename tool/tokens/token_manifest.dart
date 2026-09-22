/// Every token this generator knows how to emit, in the order it emits them.
///
/// This exists to make one specific mistake impossible. The palette that came
/// before was checked by a test that iterated the *Dart* side -- so a token
/// added to the token file and never transcribed was invisible to it: the test
/// could catch a changed value but never a missing field. Parsing validates the
/// token file against these lists in *both* directions, so an addition upstream
/// fails the build with a message naming it, and a name removed here fails just
/// as loudly.
///
/// It is therefore a checked index, never a source of truth. Values live only
/// in `design/tokens.json`.
abstract final class TokenManifest {
  /// Semantic colours, per theme. Order is the field order of `TajeerColors`,
  /// grouped the way the token file groups them: surfaces, ink, lines, brand,
  /// pressable overlays, then the four semantic quads.
  static const List<String> colors = <String>[
    'background',
    'surface',
    'surfaceMuted',
    'surfaceElevated',
    'surfaceOverlay',
    'textPrimary',
    'textSecondary',
    'textMuted',
    'textDisabled',
    'textInverse',
    'border',
    'borderSubtle',
    'borderStrong',
    'focus',
    'primary',
    'primaryHover',
    'primaryPressed',
    'primarySoft',
    'primaryForeground',
    'primaryBorder',
    'overlayHover',
    'overlayPressed',
    'successDefault',
    'successSoft',
    'successForeground',
    'successBorder',
    'warningDefault',
    'warningSoft',
    'warningForeground',
    'warningBorder',
    'dangerDefault',
    'dangerSoft',
    'dangerForeground',
    'dangerBorder',
    'infoDefault',
    'infoSoft',
    'infoForeground',
    'infoBorder',
  ];

  /// The four semantic families, and the four keys each one carries. Used by
  /// the contrast test to reason about quads rather than about 16 loose names.
  static const List<String> semanticFamilies = <String>[
    'success',
    'warning',
    'danger',
    'info',
  ];

  /// Suffixes completing a semantic family. `default` is the saturated fill,
  /// `soft` the wash, `foreground` the ink *on the wash*, `border` a decorative
  /// hairline *around the wash* -- never a control boundary.
  static const List<String> semanticKeys = <String>[
    'Default',
    'Soft',
    'Foreground',
    'Border',
  ];

  /// The six named channels. A channel *instance* takes an auto colour from the
  /// backend palette instead; these are the products themselves.
  static const List<String> channelFamilies = <String>[
    'whatsapp',
    'sms',
    'email',
    'instagram',
    'messenger',
    'liveChat',
  ];

  /// Each channel is a pair: the ink, and the chip behind it.
  static List<String> get channels => <String>[
    for (final String family in channelFamilies) ...<String>[
      family,
      '${family}Soft',
    ],
  ];

  /// The fourteen type steps, largest first.
  static const List<String> typeSteps = <String>[
    'display',
    'headlineXl',
    'headlineLg',
    'headlineMd',
    'titleLg',
    'titleMd',
    'titleSm',
    'bodyLg',
    'bodyMd',
    'bodySm',
    'labelLg',
    'labelMd',
    'labelSm',
    'caption',
  ];

  static const List<String> spaceSteps = <String>[
    '2xs',
    'xs',
    'sm',
    'md',
    'lg',
    'xl',
    '2xl',
    '3xl',
    '4xl',
  ];

  static const List<String> radiusSteps = <String>[
    'xs',
    'sm',
    'md',
    'lg',
    'xl',
    '2xl',
    'full',
  ];

  /// Elevation levels, flattest first. `popover` is deliberately not called
  /// `overlay`: `surfaceOverlay` is the modal scrim, and two different things
  /// one word apart is how the wrong one gets used.
  static const List<String> elevationLevels = <String>[
    'none',
    'subtle',
    'card',
    'floating',
    'popover',
    'modal',
  ];

  static const List<String> themes = <String>['light', 'dark'];

  /// The visual presets. A preset is a complete pair of palettes plus the
  /// elevation that goes with them; type, spacing, radii, motion and channel
  /// identity are shared, because a second spacing scale is a second design
  /// system.
  ///
  /// Every preset must define every token in [colors] and every level in
  /// [elevationLevels], in both themes -- that is what lets one component set
  /// render under all of them without naming any.
  static const List<String> presets = <String>['aurora', 'tajeer', 'teal'];

  /// The preset a fresh install wears, and the fallback for a stored value
  /// nobody recognises any more.
  static const String defaultPreset = 'tajeer';

  /// `2xs` and `4xl` are not legal Dart identifiers. One documented rule --
  /// leading digits move to the end -- applied everywhere, so nobody has to
  /// guess whether it became `xs2`, `twoXs` or `s2xs`.
  static String identifier(String token) {
    final Match? leadingDigits = RegExp(r'^(\d+)(.*)$').firstMatch(token);
    if (leadingDigits == null) {
      return token;
    }
    return '${leadingDigits.group(2)}${leadingDigits.group(1)}';
  }
}
