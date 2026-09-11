# Brand

Two layers, on purpose.

**The exports** in this folder are the source of truth — the official Tajeer AI
logo files, placed here as they came from design. They are kept in the repository
but **not bundled**: each is a large canvas that is mostly transparent margin, and
together they are several megabytes.

**`app/`** holds what the app actually ships, generated from the exports by
`build_app_assets.py`. It is the only folder `pubspec.yaml` declares.

| Export | Generated | Used for |
| --- | --- | --- |
| `en-light-mode.png` | `app/lockup_en_light.png` | the vertical logo, English, light theme |
| `en-dark-mode.png` | `app/lockup_en_dark.png` | the vertical logo, English, dark theme |
| `ar-light-mode.png` | `app/lockup_ar_light.png` | the vertical logo, Arabic, light theme |
| `ar-dark-mode.png` | `app/lockup_ar_dark.png` | the vertical logo, Arabic, dark theme |
| `horizontal.png` | `app/lockup_horizontal.png` | the horizontal logo, both themes |
| `horizontal.png` | `app/mark.png` | the mark on its own |

Nothing is redrawn, recoloured or re-typeset. Every generated file is a crop and a
resize of an export. Margins are trimmed at the first opaque pixel, and the mark is
cut at the transparent gap that separates it from the wordmark in the horizontal
logo — the script stops rather than guessing if that gap ever disappears.

## Changing the logo

Replace an export with a new one of the same name, then from `mobile/`:

```bash
python3 assets/brand/build_app_assets.py
```

and regenerate the goldens (`make golden-update`). Never edit the files in `app/`
by hand; the next run overwrites them.

## One horizontal logo, not two

There is a single horizontal export, with a yellow "Tajeer" and a gradient "AI".
Both read on the warm light canvas and on navy, so it serves both themes. If a
dark-theme horizontal version is exported, add it beside this one and teach the
script and `AppBrandLogo` about it.

## Still missing

**App icons.** Android and iOS still use Flutter's default launcher icon, by
decision, until the official app-icon exports exist — they are what people see on
their home screen and in the stores, and Android needs separate foreground and
background layers.

## Do not use

In `frontend/public/images/`: `logo.svg`, `logo-white.svg`, `logo-square.svg` and
`favicon.svg` are the retired indigo mark from before this logo system;
`logo-square.png` is a different render of the mark whose colours do not match
these exports; `ar-logo.png` has a glow baked into it.
