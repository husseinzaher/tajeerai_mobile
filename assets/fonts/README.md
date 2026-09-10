# Tajawal

The interface typeface, bundled rather than fetched at runtime: this client is
offline-first, and a font that arrives over the network renders the fallback
stack on a cold first launch — a visibly wrong face on the sign-in screen, for
exactly the users who have never seen the right one.

Three weights, and only three:

| File | Weight | Used by |
| --- | --- | --- |
| `Tajawal-Regular.ttf` | 400 | body and caption steps |
| `Tajawal-Medium.ttf` | 500 | titles and every control label |
| `Tajawal-Bold.ttf` | 700 | headlines and display |

**Tajawal has no 600.** Flutter resolves an unavailable weight by searching
upward first, so a `FontWeight.w600` request lands on 700 — and looks entirely
plausible, which is why nothing catches it. The type scale in
`design/tokens.json` therefore uses 400/500/700 only, and
`tool/build_tokens.dart` rejects any other hundred-step weight.

300 Light is unreadable at 13px on a phone, and 800/900 add nothing 700 does
not already do at display sizes. Neither is bundled.

Source: <https://github.com/google/fonts/tree/main/ofl/tajawal>, licensed under
the SIL Open Font License 1.1 — see `OFL.txt`, which must ship with the binary.
