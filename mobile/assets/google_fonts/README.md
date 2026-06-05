# Bundled Plus Jakarta Sans (✅ in place)

The app uses **Plus Jakarta Sans** as its base typeface via `google_fonts`. The
static weights are bundled here so the font loads from assets — **never over the
network** — which matters for an offline-first app and keeps tests deterministic.

`lib/main.dart` sets `GoogleFonts.config.allowRuntimeFetching = false`, and
`test/flutter_test_config.dart` does the same for tests, so a missing weight
fails loudly instead of silently downloading.

## Files present

Generated from the official open-source variable font
(`google/fonts` → `ofl/plusjakartasans`) via `fonttools` instancer, named to
match what `google_fonts` looks up by filename:

- `PlusJakartaSans-Regular.ttf`    (w400)
- `PlusJakartaSans-Medium.ttf`     (w500)
- `PlusJakartaSans-SemiBold.ttf`   (w600)
- `PlusJakartaSans-Bold.ttf`       (w700)
- `PlusJakartaSans-ExtraBold.ttf`  (w800)
- `PlusJakartaSans-Black.ttf`      (w900 → pinned to 800, the family's max)
- `OFL.txt`                        (SIL Open Font License — required)

## Regenerating (if ever needed)

```bash
curl -sSL -o VF.ttf "https://raw.githubusercontent.com/google/fonts/main/ofl/plusjakartasans/PlusJakartaSans%5Bwght%5D.ttf"
python -m pip install fonttools
# then instance wght=400/500/600/700/800 with fontTools.varLib.instancer
```
