# Changelog

All notable changes to Kinera are recorded here. Kinera follows
[semantic versioning](https://semver.org) in its 0.x form: while the API is
experimental, a minor version (0.2.0) may change it in breaking ways and a
patch version (0.1.1) only fixes. Kinera is built from source together with its
sibling AMAGE libraries; the set of versions tested together is listed in
[eco-build's releases](https://github.com/amage-si/eco-build/tree/main/releases).

## Unreleased

First version, tested with Bend 2.0.36 on Linux.

### Added

- Easing: `linear`, the CSS presets `ease`, `ease-in`, `ease-out`,
  `ease-in-out`, and `cubic-bezier`, solved by Newton steps with a bisection
  fallback.
- Springs from stiffness/damping/mass or (response, damping ratio), with the
  presets `smooth`, `snappy` and `bouncy`, evaluated in closed form for
  under-, critically and overdamped regimes, with an energy-based settle test.
- `Motion` values: `value`, `velocity`, `done`, `retarget` (from the current
  value and velocity), `settle`, `next_deadline`, and reduce-motion through
  `reduced` and `honour`.
- Helpers `lerp`, `clamp`, `progress`, `elapsed` and `started` on a
  wrap-aware `U32` millisecond clock.
- 52 native checks against a float64 Python reference, the hover example and
  the per-call cost benchmark.
