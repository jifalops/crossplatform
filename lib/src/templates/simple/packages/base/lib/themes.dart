import 'package:shared_theme/shared_theme.dart';

/// See the theme colors at
/// https://material.io/tools/color/#!/?primary.color=PRIMARY_COLOR&secondary.color=SECONDARY_COLOR
final themeset = ThemeSet(themes: [
  Theme(
      name: 'Light',
      brightness: Brightness.light,
      colors: _lightColors,
      fonts: _darkFonts,
      elements: _lightElements),
  Theme(
      name: 'Dark',
      brightness: Brightness.dark,
      colors: _darkColors,
      fonts: _lightFonts,
      elements: _darkElements),
], fontFaces: _fontFaces);

//
// Colors
//

// Brand colors are declared here so they can be used repeatedly and as default
// constructor args.
const _primary = ContrastingColors(Color(0xFFPRIMARY_COLOR), ON_PRIMARY_COLOR);
const _primaryLight = ContrastingColors(Color(0xFFPRIMARY_COLOR_LIGHT), ON_PRIMARY_COLOR_LIGHT);
const _primaryDark = ContrastingColors(Color(0xFFPRIMARY_COLOR_DARK), ON_PRIMARY_COLOR_DARK);
const _secondary = ContrastingColors(Color(0xFFSECONDARY_COLOR), ON_SECONDARY_COLOR);
const _secondaryLight = ContrastingColors(Color(0xFFSECONDARY_COLOR_LIGHT), ON_SECONDARY_COLOR_LIGHT);
const _secondaryDark = ContrastingColors(Color(0xFFSECONDARY_COLOR_DARK), ON_SECONDARY_COLOR_DARK);
const _error = ContrastingColors(Colors.error, Colors.onError);

const _lightColors = _ThemeColors(
  background: ContrastingColors(Color(0xFFfefefe), Colors.black),
  surface: ContrastingColors(Color(0xFFfefefe), Colors.black),
  divider: ContrastingColors(Color(0xFFeeeeee), Colors.black),
);

const _darkColors = _ThemeColors(
  background: ContrastingColors(Color(0xFF333333), Colors.white),
  surface: ContrastingColors(Color(0xFF333333), Colors.white),
  divider: ContrastingColors(Color(0xFF484848), Colors.white),
);

class _ThemeColors extends ColorSet {
  const _ThemeColors({
    ContrastingColors background,
    ContrastingColors surface,
    ContrastingColors divider,
  }) : super(
          primary: _primary,
          primaryLight: _primaryLight,
          primaryDark: _primaryDark,
          secondary: _secondary,
          secondaryLight: _secondaryLight,
          secondaryDark: _secondaryDark,
          error: _error,
          background: background,
          scaffold: surface,
          dialog: surface,
          card: surface,
          divider: divider,
          selectedRow: divider,
          indicator: _secondary,
          textSelection: _primaryLight,
          textSelectionHandle: _primaryDark,
        );
}

//
// Elements
//

/// The default elements.
final _lightElements = ElementSet(
  primaryButton: _ButtonBase(
      color: _secondary.color,
      font: _darkFonts.button.copyWith(color: _secondary.contrast, size: 16.0),
      shadow: ShadowElevation.dp8),
  secondaryButton: _ButtonBase(
      color: _primary.color,
      font: _darkFonts.button.copyWith(color: _primary.contrast)),
  tertiaryButton: _ButtonBase(),
  inputBase: Element.outlineInput,
);

/// Use a different text color on the tertiary button.
final _darkElements = _lightElements.copyWith(
    tertiaryButton: _lightElements.tertiaryButton.copyWith(
        font: _lightElements.tertiaryButton.font
            .copyWith(color: _lightFonts.button.color)));

class _ButtonBase extends Element {
  _ButtonBase(
      {Color color: Colors.transparent,
      Font font,
      ShadowElevation shadow: ShadowElevation.none})
      : super(
            align: TextAlign.center,
            padding: BoxSpacing.symmetric(vertical: 4.0, horizontal: 8.0),
            border: Border(radii: BorderRadius(4.0)),
            font: font ?? _darkFonts.button,
            shadow: shadow,
            color: color);
}

//
// Fonts
//

/// The default fonts.
final _darkFonts = FontSet.dark.apply(/*family: 'Open Sans'*/)
  .copyWith(/* Your desired font settings... */);

final _lightFonts = _darkFonts.lighten();

/// These will be included in the CSS, but currently must be manually copied
/// into your Flutter app's pubspec.yaml. The URL is exactly the same though.
final _fontFaces = [
  // FontFace(
  //     family: 'Open Sans',
  //     url: 'packages/sharedtheme_example/assets/fonts/OpenSans-Regular.ttf'),
];
