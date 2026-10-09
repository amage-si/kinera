# Kinera API

Kinera depends only on `Base` from the official Bend toolchain. Import paths
are relative to the calling file. An application next to the `Kinera`
directory uses:

```bend
import Base
import ./Kinera/main.bend as K
```

Everything lives in `main.bend`. All functions are pure and total: invalid
numbers are clamped or replaced by documented defaults, never reported as
errors, so an animation can never stop a frame from being drawn.

## Units

| Quantity | Type and unit |
| --- | --- |
| Clock (`now`, `start`) | `U32` milliseconds on one monotonic clock |
| Durations, spring response | `F32` milliseconds |
| Velocity | `F32` value units per **second** |
| Stiffness, damping, mass | seconds-based physics (as CSS, UIKit, SwiftUI) |
| Animated value | `F32`, any unit (opacity, pixels, a mix factor) |

**Why a `U32` millisecond clock.** `IO.now()` answers whole milliseconds of
the monotonic clock, and Ankra hands apps the same clock per frame. An integer
clock is exact and never loses precision over a long session, while an `F32`
millisecond clock has 0.25 ms steps after one hour and 8 ms steps (a whole
120 Hz frame) after a day. Kinera subtracts in `U32`, which wraps, and reads a
difference of 2^31 or more as "before the start", so the raw truncated
`IO.now()` keeps working across the 49.7-day wrap. The elapsed time is then an
exact `F32`. Sub-millisecond time is not represented; at 120 Hz a 1 ms
quantization is at most one eighth of a frame step.

The one consequence of wrapping: a motion more than 24.8 days past its start
reads as not started. A motion that has reached its target with no velocity
is unaffected (see `done`), and `settle` turns any finished motion into one.

## Numbers

| Function | Contract |
| --- | --- |
| `finite(x)` | False for NaN and the infinities. |
| `finite_or(x, d)`, `positive_or(x, d)` | `x` when finite (and above 0), else `d`. |
| `clamp(x, lo, hi)` | Into `[lo, hi]`; NaN becomes `lo`. |
| `lerp(a, b, t)` | `a + (b - a) t`, unclamped. |
| `elapsed(now, start)` | Milliseconds since `start` as `F32`; 0 before it (wrap-aware). |
| `started(now, start)` | True once `now` reaches `start` (wrap-aware). |
| `progress(now, start, duration)` | Fraction of `duration` ms elapsed, in `[0, 1]`. A zero, negative or non-finite duration gives 1. |

## Easing

```bend
type Ease is Data:
  Linear{}
  Cubic{ax: F32, bx: F32, cx: F32, ay: F32, by: F32, cy: F32}
```

`Cubic` holds polynomial coefficients; build it with `cubic_bezier`.

| Function | Contract |
| --- | --- |
| `linear()` | `p`. |
| `ease()`, `ease_in()`, `ease_out()`, `ease_in_out()` | The CSS presets: `cubic-bezier(.25,.1,.25,1)`, `(.42,0,1,1)`, `(0,0,.58,1)`, `(.42,0,.58,1)`. |
| `cubic_bezier(x1, y1, x2, y2)` | CSS `cubic-bezier`. `x1`, `x2` clamped into `[0, 1]`; `y1`, `y2` free (overshoot allowed); any non-finite parameter gives `Linear`. |
| `ease_at(e, p)` | Eased progress. `p` is clamped into `[0, 1]` (NaN reads as 0); `ease_at(e, 0) = 0` and `ease_at(e, 1) = 1` exactly. |
| `ease_slope(e, p)` | d ease / d p; at the ends, the limit taken 1e-4 inside the curve. |

`ease_at` solves `x(t) = p` as browsers do: up to 8 Newton steps from `t = p`,
stopping within 1e-7, then a check that `|x(t) - p| < 1e-5`; if that fails,
24 bisection steps on `[0, 1]`. Measured against a float64 reference at
p = 0.1, 0.25, 0.5, 0.75, 0.9, the worst error is 4.6e-7 for the CSS presets
and 3.0e-6 for the extreme `cubic-bezier(1, 0, 0, 1)`.

## Springs

```bend
type Damping is Data:
  Under{decay: F32, wd: F32}
  Critical{}
  Over{r1: F32, r2: F32}

type Spring is Data:
  Spring{omega: F32, damping: Damping, rest: F32, rest_speed: F32}
```

A spring is a damped harmonic oscillator, `x'' + 2 zeta omega x' + omega^2 x
= 0` on the displacement from the target. It is evaluated in closed form at
any time, so results do not depend on the frame rate or on how often it is
sampled:

- underdamped (`zeta < 0.999`):
  `x = e^(-zeta omega t) (x0 cos wd t + (v0 + zeta omega x0) / wd sin wd t)`,
  `wd = omega sqrt(1 - zeta^2)`;
- critical (`|zeta - 1| <= 0.001`): `x = (x0 + (v0 + omega x0) t) e^(-omega t)`;
- overdamped (`zeta > 1.001`): `x = c1 e^(r1 t) + c2 e^(r2 t)`, with
  `r1 = -omega / q`, `r2 = -omega q`, `q = zeta + sqrt(zeta^2 - 1)` (the
  stable form of the two roots).

The velocity is the exact derivative of each form. A ratio within 0.001 of 1
is evaluated as critical; the difference is of order 0.001 of the motion.

| Function | Contract |
| --- | --- |
| `responsive(response, ratio)` | SwiftUI form: `response` is the undamped period in ms (its perceptual duration), `ratio` the damping ratio (1 critical, below 1 bouncy). `omega = 2 pi 1000 / response`. |
| `physical(stiffness, damping, mass)` | `omega = sqrt(k / m)`, `zeta = c / (2 sqrt(k m))`. |
| `smooth()`, `snappy()`, `bouncy()` | SwiftUI's presets: 500 ms response, ratio 1, 0.85 and 0.7. |
| `with_rest(s, rest, rest_speed)` | Replaces the settle epsilons. |
| `spring_of(omega, zeta, rest, rest_speed)` | The core constructor (rad/s). |

Sanitizing, so that every spring is valid and settles:

- `omega` clamped to `[0.01, 10000]` rad/s; non-finite gives `4 pi` (a 500 ms
  response);
- `zeta` clamped to `[0.01, 100]`; NaN gives 1. Zero or negative damping
  therefore still decays (at ratio 0.01);
- a non-positive or non-finite `response` gives 500 ms; a non-positive or
  non-finite `stiffness` gives 157.91, and `mass` gives 1;
- `rest` and `rest_speed` clamped to `[1e-6, 1e6]`; non-finite gives the
  defaults 0.001 (value units) and 0.01 (units per second).

**Settled.** A spring is settled when

```text
omega^2 x^2 + v^2 <= min(omega^2 rest^2, rest_speed^2)
```

This implies `|x| <= rest` and `|v| <= rest_speed`. The left side is twice the
oscillator's energy per unit mass, which damping never lets grow, so once a
spring is settled it stays settled: `done` never flips back to false (tested
every millisecond for 3 s). Settled springs read exactly their target with
zero velocity. For a 0 -> 1 motion with the defaults: smooth settles at
782 ms, snappy at 746 ms, bouncy at 873 ms. For pixel-sized values, a `rest` of
0.01 to 0.1 settles sooner with no visible difference.

## Curves

```bend
type Curve is Data:
  Tween{duration: F32, ease: Ease}
  Physics{spring: Spring}
```

| Function | Contract |
| --- | --- |
| `tween(duration, e)` | A timed curve. Non-finite or negative durations become 0; at most 1e7 ms. |
| `spring(s)` | A spring curve. |
| `instant()` | `Tween{0, Linear}`: jumps to the target at its start. |
| `honour(reduce, c)` | `instant()` when `reduce` is true, else `c`. |

## Motion

```bend
type Motion is Data:
  Motion{curve: Curve, target: F32, start: U32, from: F32, v0: F32}
```

One animated number: heading for `target` under `curve`, having left `from`
with velocity `v0` at clock `start`. It is a small record (no lists, arrays or
closures), cheap to copy and store per property.

| Function | Contract |
| --- | --- |
| `rest(c, value)` | A motion at rest at `value`. |
| `animate(c, now, from, to)` | From `from` at rest to `to`, starting at `now`. |
| `value(m, now)` | The value at `now`. Before `start`: `from`. Once done: exactly `target`. |
| `velocity(m, now)` | Units per second. Before `start`: `v0`. Once done: 0. A tween reports `delta * ease_slope / duration`. |
| `done(m, now)` | True once the value no longer changes: a tween at `start + duration`, a spring once settled. A motion whose `from` equals its `target` with `v0 = 0` is done at any time, whatever the clock reads. |
| `next_deadline(m, now, frame_ms)` | `None` once done: **no more frames**. `Some{start}` while a delayed motion waits. Otherwise `Some{now + frame_ms}` (a `frame_ms` of 0 counts as 1). |
| `retarget(m, now, to)` | Heads for `to` from `value(m, now)` **and** `velocity(m, now)`, starting at `now`. A non-finite `to`, or `to` equal to the current target, returns `m` unchanged (so repeated hover events do not restart a tween). |
| `settle(m, now)` | Once done, `rest(curve, target)`; otherwise `m`. |
| `reduced(m)` | Reduce-motion: at rest at the target now, curve kept. |
| `target(m)`, `curve(m)` | Accessors. |

**Interruption.** A spring retargeted mid-flight keeps its value and its
velocity, so hover-in then hover-out reverses smoothly: the value carries on
briefly in its old direction, turns, and settles at the new target with no
jump. A tween retargeted mid-flight starts from its current value and runs its
full duration from there; its velocity restarts from the ease's start slope.
Prefer springs for anything the user can interrupt.

**Reduce motion.** Kinera's choice is to jump: `reduced(m)` lands on the
target at once and `honour(True{}, c)` makes every later retarget instant, so
no frames are scheduled at all. A short fade is a property of what is drawn
(an opacity), not of a number, so it belongs to the host: Mokko can keep a
brief opacity tween while it jumps positions and sizes.

## Driving it from a host

```bend
# On an event: start or reverse.
m2 = K.retarget(m, now, 1.0)
# On each frame at time `now`:
opacity = K.value(m2, now)
next = K.next_deadline(m2, now, 8)   # None: stop scheduling frames
```

`examples/hover.bend` runs this loop on a 120 Hz grid and prints every frame.

## Cost

`examples/bench.bend` times one million calls (Bend 2.0.36, `--threads 2`,
this Linux machine, an empty loop costs 1 ms per million):

| Call | Per call |
| --- | --- |
| `value`, linear tween | ~4 ns |
| `value`, critical spring (smooth) | ~9 ns |
| `value`, overdamped spring | ~14 ns |
| `value`, ease-in-out tween | ~27 ns |
| `value`, underdamped spring (bouncy) | ~30 ns |
| `velocity`, bouncy | ~28 ns |
| `done`, bouncy | ~30 ns |

A thousand animated properties per frame cost about 30 µs.
