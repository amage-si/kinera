# Kinera

**Motion math for the AMAGE UI ecosystem, in Bend 2.**

Kinera turns time into numbers: CSS easing curves, damped springs and small
motion values that can be retargeted mid-flight. It is pure Bend with no IO
and depends only on `Base`. Every value is computed in closed form from the
clock, so animations are deterministic and independent of the frame rate, and
a finished motion tells its host that no more frames are needed.

**Status:** early implementation, tested with **Bend 2.0.37** on Linux. The
first priority is a polished, reliable experience on the development Linux
machine. Compatibility layers will follow proven progress.

## What works today

- Easing: `linear` and the CSS presets `ease`, `ease-in`, `ease-out`,
  `ease-in-out`, plus general `cubic-bezier(x1, y1, x2, y2)`, solved with
  Newton steps and a bisection fallback as browsers do. Worst error against a
  float64 reference: 4.6e-7 for the presets.
- Springs from stiffness/damping/mass or from SwiftUI's (response, damping
  ratio), with the presets `smooth`, `snappy` and `bouncy`. Position and
  velocity come from the closed form for under-, critically and overdamped
  springs at any time; worst relative error against the reference is 3.4e-5.
- "Settled" from a position and a velocity epsilon, checked through the
  spring's energy so a settled spring never wakes up again.
- `Motion` values with `value`, `velocity`, `done`, `retarget`, `settle` and
  `next_deadline`. Retargeting starts from the current value and velocity, so
  hover-in then hover-out reverses with no jump.
- Reduce-motion: `reduced(m)` and `honour(reduce, curve)` jump to the target.
- Total functions: NaN, infinite, zero and negative inputs are clamped or
  replaced by documented defaults; clocks may wrap.
- About 4 to 30 ns per `value()` call.

The native suite has **52 checks**: the presets and two custom curves against
the Python reference, four springs (with and without initial velocity) at six
times each, settle times, settled springs staying settled, continuity across a
retarget, re-anchoring at 60 Hz, 120 Hz and 1 kHz matching direct evaluation,
`done`/`next_deadline` at the end, reduce-motion and edge cases.

## Quick start

Requirements: the [Bend 2 toolchain](https://bend-lang.com) and Clang 14 or
newer. No display is needed and Kinera has no sibling dependencies.

```sh
git clone https://github.com/amage-si/kinera.git Kinera
cd Kinera
export BEND_NO_TELEMETRY=1
bend version
mkdir -p build
bend tests.bend -o build/tests
./build/tests --threads 2 --gpu off
```

Run the hover example: a snappy spring heads for opacity 1, the pointer leaves
at 120 ms, and the host draws on a 120 Hz grid until it is told to stop:

```sh
bend examples/hover.bend -o build/hover
./build/hover --threads 2 --gpu off
```

```text
  t=0 ms  opacity=0  velocity=0/s
  t=8 ms  opacity=0.004773259  velocity=1.1592994/s
  ...
  t=120 ms  opacity=0.48601592  velocity=4.7234497/s
  t=128 ms  opacity=0.51837254  velocity=3.396677/s
  ...
  t=160 ms  opacity=0.5616598  velocity=-0.30657437/s
  ...
  t=864 ms  opacity=0  velocity=0/s
idle after 109 frames: no more frames needed
```

## The motion contract

```bend
import Base
import ./Kinera/main.bend as K

def frame(m: K.Motion, now: U32) -> F32:
  K.value(m, now)

def main() -> IO(Unit):
  +m = K.retarget(K.rest(K.spring(K.snappy()), 0.0), 1000, 1.0)
  IO.print(F32.show(frame(m, 1100)))
```

Clocks are `U32` milliseconds of one monotonic clock (`IO.now()`'s, which
Ankra hands apps per frame); durations and spring responses are `F32`
milliseconds; velocities are units per second. `next_deadline(m, now,
frame_ms)` answers `None` once the motion is done, so a host returns to zero
frames and zero wakeups. Read the [API reference](docs/api.md) for every
function, unit, default and bound.

## Current boundaries

- Numbers only. Colour interpolation belongs to Chromi (OKLab mixing); Kinera
  animates the mix factor.
- One dimension per motion. A point or a rectangle is two or four motions.
- No keyframes, sequences, staggering or delays beyond a start time in the
  future; no decay (inertial scrolling) curve yet.
- A retargeted tween restarts its full duration from the current value; it
  does not shorten reversals as CSS transitions do.
- Clock resolution is 1 ms. A motion more than 24.8 days past its start reads
  as not started, unless it is at rest (see `settle`).
- Spring ratios within 0.001 of 1 are evaluated as critical; ratios are
  clamped to `[0.01, 100]`, so an undamped spring does not exist.
- Costs are measured on this machine (`examples/bench.bend`); no profile
  across other CPUs exists.

`ALL PROOFS CHECK` from the Bend checker covers types and termination. No laws
about the curves (monotone easing, energy decay) are stated as Bend proofs yet;
the tests are separate, partial evidence.

## Repository map

| Path | Purpose |
| --- | --- |
| [main.bend](main.bend) | Numbers, easing, springs, curves and `Motion`. |
| [tests.bend](tests.bend) | Native checks against the Python reference; no display needed. |
| [examples/hover.bend](examples/hover.bend) | A hover reversal driven frame by frame, printed to the terminal. |
| [examples/bench.bend](examples/bench.bend) | Cost per `value`, `velocity` and `done` call. |
| [docs/api.md](docs/api.md) | Types, units, defaults, bounds and behavior. |

## Used by

Mokko's transitions (hover fade, focus ring, press, caret) and Kairo's
animated dirty regions are the planned first users. Import it as
`../Kinera/main.bend` from a sibling directory.

## Direction

Next: Mokko transitions on top of `Motion`, a decay curve for inertial
scrolling, keyframe sequences, and laws for the curve properties checked by
Bend itself. These are goals, not supported features.

See [CONTRIBUTING.md](CONTRIBUTING.md) for development rules. The API is
experimental and may change.

## License

Licensed under either of

- Apache License, Version 2.0 ([LICENSE-APACHE](LICENSE-APACHE))
- MIT license ([LICENSE-MIT](LICENSE-MIT))

at your option. Unless you explicitly state otherwise, any contribution
intentionally submitted for inclusion in this work, as defined in the
Apache-2.0 license, shall be dual licensed as above, without any additional
terms or conditions.
