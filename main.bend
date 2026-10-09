import Base

# Kinera: motion math for the AMAGE UI ecosystem.
#
# Units: clocks are U32 milliseconds on one monotonic clock (IO.now's);
# durations and spring responses are F32 milliseconds; velocities are value
# units per second; stiffness, damping and mass use seconds, as in CSS, UIKit
# and SwiftUI springs. See docs/api.md for the full contract.

# Numbers
# -------

# True for every F32 except NaN and the infinities.
def finite(+x: F32) -> Bool:
  F32.is_eq((x - x : F32), 0.0)

# `x` when finite, else `fallback`.
def finite_or(+x: F32, fallback: F32) -> F32:
  Bool.pick(F32, finite(x), x, fallback)

# `x` when finite and above zero, else `fallback`.
def positive_or(+x: F32, fallback: F32) -> F32:
  Bool.pick(F32, Bool.and(finite(x), (x > 0.0 : F32)), x, fallback)

# Clamps into [lo, hi]; NaN becomes `lo`.
def clamp(+x: F32, +lo: F32, hi: F32) -> F32:
  Bool.pick(F32, F32.is_eq(x, x), F32.clamp(x, lo, hi), lo)

# a + (b - a) * t, unclamped (t outside [0, 1] extrapolates).
def lerp(a: F32, b: F32, t: F32) -> F32:
  F32.lerp(a, b, t)

# Milliseconds from `start` to `now`, wrapping in U32: a difference of 2^31
# or more means `now` is before `start`, and reads as 0.
def elapsed(+now: U32, +start: U32) -> F32:
  +d = (now - start : U32)
  Bool.pick(F32, (d < 2147483648 : U32), U32.to_f32(d), 0.0)

# True once `now` has reached `start` (wrap-aware, see `elapsed`).
def started(+now: U32, +start: U32) -> Bool:
  ((now - start : U32) < 2147483648 : U32)

# Fraction of `duration` (ms) elapsed since `start`, in [0, 1]. A duration
# that is zero, negative or not finite is complete at once.
def progress_of(+t: F32, +duration: F32) -> F32:
  Bool.pick(F32, Bool.and(finite(duration), (duration > 0.0 : F32)), clamp((t / duration : F32), 0.0, 1.0), 1.0)

def progress(now: U32, start: U32, duration: F32) -> F32:
  progress_of(elapsed(now, start), duration)

# Easing
# ------

# A cubic Bezier from (0, 0) to (1, 1), kept as polynomial coefficients:
# x(t) = ((ax t + bx) t + cx) t, and the same for y.
type Ease is Data:
  Linear{}
  Cubic{ax: F32, bx: F32, cx: F32, ay: F32, by: F32, cy: F32}

def cubic(+x1: F32, +y1: F32, +x2: F32, +y2: F32) -> Ease:
  +cx = (3.0 * x1 : F32)
  +bx = ((3.0 * (x2 - x1 : F32) : F32) - cx : F32)
  +cy = (3.0 * y1 : F32)
  +by = ((3.0 * (y2 - y1 : F32) : F32) - cy : F32)
  Cubic{(1.0 - cx - bx : F32), bx, cx, (1.0 - cy - by : F32), by, cy}

def cubic_if(ok: Bool, x1: F32, y1: F32, x2: F32, y2: F32) -> Ease:
  match ok:
    case False{}:
      Linear{}
    case True{}:
      cubic(F32.clamp(x1, 0.0, 1.0), y1, F32.clamp(x2, 0.0, 1.0), y2)

# CSS cubic-bezier(x1, y1, x2, y2). x1 and x2 are clamped into [0, 1] (CSS
# rejects them outside, which would make x(t) non-monotone); y1 and y2 may
# overshoot. A non-finite parameter yields `Linear`.
def cubic_bezier(+x1: F32, +y1: F32, +x2: F32, +y2: F32) -> Ease:
  cubic_if(finite(x1) && finite(y1) && finite(x2) && finite(y2), x1, y1, x2, y2)

def linear() -> Ease:
  Linear{}

def ease() -> Ease:
  cubic(0.25, 0.1, 0.25, 1.0)

def ease_in() -> Ease:
  cubic(0.42, 0.0, 1.0, 1.0)

def ease_out() -> Ease:
  cubic(0.0, 0.0, 0.58, 1.0)

def ease_in_out() -> Ease:
  cubic(0.42, 0.0, 0.58, 1.0)

def poly(+a: F32, +b: F32, +c: F32, +t: F32) -> F32:
  (((a * t + b : F32) * t + c : F32) * t : F32)

def dpoly(+a: F32, +b: F32, +c: F32, +t: F32) -> F32:
  ((3.0 * a * t + 2.0 * b : F32) * t + c : F32)

# Newton's method on x(t) = p from t = p, at most `n` steps; `more` turns
# False once a step lands within 1e-7. x'(t) >= 0 for x1, x2 in [0, 1].
def newton(n: Nat, more: Bool, +ax: F32, +bx: F32, +cx: F32, +p: F32, +t: F32) -> F32:
  match n more:
    case 0n _:
      t
    case 1n+k False{}:
      t
    case 1n+k True{}:
      +err = (poly(ax, bx, cx, t) - p : F32)
      +slope = F32.max(dpoly(ax, bx, cx, t), 0.000001)
      newton(k, (F32.abs(err) > 0.0000001 : F32), ax, bx, cx, p, F32.clamp((t - (err / slope : F32) : F32), 0.0, 1.0))

# Bisection on [lo, hi]: 24 halvings reach F32 resolution.
def bisect(n: Nat, +ax: F32, +bx: F32, +cx: F32, +p: F32, +lo: F32, +hi: F32) -> F32:
  match n:
    case 0n:
      ((lo + hi : F32) * 0.5 : F32)
    case 1n+k:
      +mid = ((lo + hi : F32) * 0.5 : F32)
      +below = (poly(ax, bx, cx, mid) < p : F32)
      bisect(k, ax, bx, cx, p, Bool.pick(F32, below, mid, lo), Bool.pick(F32, below, hi, mid))

def solve_done(ok: Bool, +ax: F32, +bx: F32, +cx: F32, +p: F32, t: F32) -> F32:
  match ok:
    case True{}:
      t
    case False{}:
      bisect(24n, ax, bx, cx, p, 0.0, 1.0)

# The curve parameter t with x(t) = p: Newton first, bisection as fallback,
# as browsers do.
def solve(+ax: F32, +bx: F32, +cx: F32, +p: F32) -> F32:
  +t = newton(8n, True{}, ax, bx, cx, p, p)
  solve_done((F32.abs((poly(ax, bx, cx, t) - p : F32)) < 0.00001 : F32), ax, bx, cx, p, t)

def inside(+p: F32) -> Bool:
  (p > 0.0 : F32) && (p < 1.0 : F32)

def cubic_at(ok: Bool, +ax: F32, +bx: F32, +cx: F32, +ay: F32, +by: F32, +cy: F32, +p: F32) -> F32:
  match ok:
    case False{}:
      clamp(p, 0.0, 1.0)
    case True{}:
      poly(ay, by, cy, solve(ax, bx, cx, p))

# Eased progress for p in [0, 1]; p is clamped first (NaN reads as 0), and
# the ends are exact: 0 gives 0 and 1 gives 1.
def ease_at(e: Ease, +p: F32) -> F32:
  match e:
    case Linear{}:
      clamp(p, 0.0, 1.0)
    case Cubic{+ax, +bx, +cx, +ay, +by, +cy}:
      cubic_at(inside(p), ax, bx, cx, ay, by, cy, p)

def cubic_slope(+ax: F32, +bx: F32, +cx: F32, +ay: F32, +by: F32, +cy: F32, +t: F32) -> F32:
  (dpoly(ay, by, cy, t) / F32.max(dpoly(ax, bx, cx, t), 0.000001) : F32)

# d ease / d p at p (clamped). At the very ends the slope is taken a hair
# inside the curve, where 0/0 forms have a finite limit.
def ease_slope(e: Ease, +p: F32) -> F32:
  match e:
    case Linear{}:
      1.0
    case Cubic{+ax, +bx, +cx, +ay, +by, +cy}:
      cubic_slope(ax, bx, cx, ay, by, cy, F32.clamp(solve(ax, bx, cx, clamp(p, 0.0, 1.0)), 0.0001, 0.9999))

# Springs
# -------

# The regime of a damped harmonic oscillator, with what its closed form needs.
type Damping is Data:
  Under{decay: F32, wd: F32}
  Critical{}
  Over{r1: F32, r2: F32}

# omega: natural angular frequency (rad/s). rest: position epsilon (value
# units); rest_speed: velocity epsilon (units per second).
type Spring is Data:
  Spring{omega: F32, damping: Damping, rest: F32, rest_speed: F32}

# A damping ratio within 0.001 of 1 is treated as critical.
def damping_pick(under: Bool, over: Bool, +omega: F32, +zeta: F32) -> Damping:
  match under over:
    case True{} _:
      Under{(zeta * omega : F32), (omega * F32.sqrt((1.0 - (zeta * zeta : F32) : F32)) : F32)}
    case False{} True{}:
      +q = (zeta + F32.sqrt(((zeta * zeta : F32) - 1.0 : F32)) : F32)
      Over{(F32.neg(omega) / q : F32), (F32.neg(omega) * q : F32)}
    case False{} False{}:
      Critical{}

# The core constructor. omega is clamped to [0.01, 10000] rad/s (NaN: 4 pi,
# a 500 ms response); zeta to [0.01, 100] (NaN: 1), so every spring settles;
# rest and rest_speed to [1e-6, 1e6] (non-finite: 0.001 and 0.01).
def spring_of(omega: F32, zeta: F32, rest: F32, rest_speed: F32) -> Spring:
  +w = clamp(finite_or(omega, 12.566371), 0.01, 10000.0)
  +z = clamp(finite_or(zeta, 1.0), 0.01, 100.0)
  Spring{w, damping_pick((z < 0.999 : F32), (z > 1.001 : F32), w, z), clamp(finite_or(rest, 0.001), 0.000001, 1000000.0), clamp(finite_or(rest_speed, 0.01), 0.000001, 1000000.0)}

# A spring from its physics: stiffness k (N/m), damping c (N s/m), mass m
# (kg). Non-positive or non-finite k and m fall back to 157.91 and 1 (a
# 500 ms response); a negative damping clamps to the minimum ratio.
def physical(stiffness: F32, damping: F32, mass: F32) -> Spring:
  +k = positive_or(stiffness, 157.91367)
  +m = positive_or(mass, 1.0)
  spring_of(F32.sqrt((k / m : F32)), (damping / (2.0 * F32.sqrt((k * m : F32)) : F32) : F32), 0.001, 0.01)

# A spring as SwiftUI states it: `response` is the period of the undamped
# oscillation in ms (its perceptual duration), `ratio` the damping ratio
# (1 critical, below 1 bouncy). A non-positive response falls back to 500.
def responsive(response: F32, ratio: F32) -> Spring:
  spring_of((6283.1853 / positive_or(response, 500.0) : F32), ratio, 0.001, 0.01)

# Replaces the settle epsilons (position in value units, speed per second).
def with_rest(s: Spring, rest: F32, rest_speed: F32) -> Spring:
  match s:
    case Spring{omega, damping, r, v}:
      Spring{omega, damping, clamp(finite_or(rest, 0.001), 0.000001, 1000000.0), clamp(finite_or(rest_speed, 0.01), 0.000001, 1000000.0)}

# Presets, as SwiftUI's .smooth, .snappy and .bouncy: 500 ms response,
# damping ratio 1, 0.85 and 0.7.
def smooth() -> Spring:
  responsive(500.0, 1.0)

def snappy() -> Spring:
  responsive(500.0, 0.85)

def bouncy() -> Spring:
  responsive(500.0, 0.7)

# Displacement x and velocity v at one instant.
type State is Data:
  State{x: F32, v: F32}

def under_state(+decay: F32, +wd: F32, +omega: F32, +x0: F32, +v0: F32, +e: F32, +c: F32, +s: F32) -> State:
  State{(e * ((x0 * c : F32) + (((v0 + (decay * x0 : F32) : F32) / wd : F32) * s : F32) : F32) : F32), (e * ((v0 * c : F32) - ((((omega * omega : F32) * x0 : F32) + (decay * v0 : F32) : F32) / wd * s : F32) : F32) : F32)}

def critical_state(+omega: F32, +x0: F32, +v0: F32, +t: F32, +e: F32) -> State:
  +b = (v0 + (omega * x0 : F32) : F32)
  State{((x0 + (b * t : F32) : F32) * e : F32), ((v0 - ((omega * b : F32) * t : F32) : F32) * e : F32)}

def over_state(+r1: F32, +r2: F32, +x0: F32, +e1: F32, +e2: F32, +c2: F32) -> State:
  +c1 = (x0 - c2 : F32)
  State{((c1 * e1 : F32) + (c2 * e2 : F32) : F32), (((r1 * c1 : F32) * e1 : F32) + ((r2 * c2 : F32) * e2 : F32) : F32)}

# Closed form at t seconds, from displacement x0 and velocity v0.
def spring_state(+omega: F32, d: Damping, +x0: F32, +v0: F32, +t: F32) -> State:
  match d:
    case Under{+decay, +wd}:
      under_state(decay, wd, omega, x0, v0, F32.exp(F32.neg((decay * t : F32))), F32.cos((wd * t : F32)), F32.sin((wd * t : F32)))
    case Critical{}:
      critical_state(omega, x0, v0, t, F32.exp(F32.neg((omega * t : F32))))
    case Over{+r1, +r2}:
      over_state(r1, r2, x0, F32.exp((r1 * t : F32)), F32.exp((r2 * t : F32)), ((v0 - (r1 * x0 : F32) : F32) / (r2 - r1 : F32) : F32))

# Settled when the oscillator's energy, which damping never lets grow, is
# below both epsilons: omega^2 x^2 + v^2 <= min(omega^2 rest^2, rest_speed^2).
# That implies |x| <= rest and |v| <= rest_speed, and once true stays true.
def calm(+omega: F32, +rest: F32, +rest_speed: F32, st: State) -> Bool:
  match st:
    case State{+x, +v}:
      +wx = (omega * x : F32)
      +wr = (omega * rest : F32)
      (((wx * wx : F32) + (v * v : F32) : F32) <= F32.min((wr * wr : F32), (rest_speed * rest_speed : F32)) : F32)

def state_x(st: State) -> F32:
  match st:
    case State{x, v}:
      x

def state_v(st: State) -> F32:
  match st:
    case State{x, v}:
      v

def snap_value(settled: Bool, +target: F32, st: State) -> F32:
  match settled:
    case True{}:
      target
    case False{}:
      (target + state_x(st) : F32)

def snap_velocity(settled: Bool, st: State) -> F32:
  match settled:
    case True{}:
      0.0
    case False{}:
      state_v(st)

def spring_value(s: Spring, +target: F32, +x0: F32, +v0: F32, +t: F32) -> F32:
  match s:
    case Spring{+omega, d, +rest, +rest_speed}:
      +st = spring_state(omega, d, x0, v0, t)
      snap_value(calm(omega, rest, rest_speed, st), target, st)

def spring_velocity(s: Spring, +x0: F32, +v0: F32, +t: F32) -> F32:
  match s:
    case Spring{+omega, d, +rest, +rest_speed}:
      +st = spring_state(omega, d, x0, v0, t)
      snap_velocity(calm(omega, rest, rest_speed, st), st)

def spring_done(s: Spring, +x0: F32, +v0: F32, +t: F32) -> Bool:
  match s:
    case Spring{+omega, d, +rest, +rest_speed}:
      calm(omega, rest, rest_speed, spring_state(omega, d, x0, v0, t))

# Curves
# ------

type Curve is Data:
  Tween{duration: F32, ease: Ease}
  Physics{spring: Spring}

# A tween of `duration` ms. Non-finite or negative durations become 0 (the
# motion completes at its start); durations clamp to at most 1e7 ms.
def tween(+duration: F32, e: Ease) -> Curve:
  Tween{clamp(finite_or(duration, 0.0), 0.0, 10000000.0), e}

def spring(s: Spring) -> Curve:
  Physics{s}

# A zero-length tween: jumps to its target.
def instant() -> Curve:
  Tween{0.0, Linear{}}

# Honours a reduce-motion preference: with `reduce` on, every curve becomes
# `instant()`.
def honour(reduce: Bool, c: Curve) -> Curve:
  match reduce:
    case True{}:
      instant()
    case False{}:
      c

def tween_value(more: Bool, e: Ease, +target: F32, from: F32, +p: F32) -> F32:
  match more:
    case False{}:
      target
    case True{}:
      F32.lerp(from, target, ease_at(e, p))

def tween_velocity(more: Bool, e: Ease, delta: F32, duration: F32, +p: F32) -> F32:
  match more:
    case False{}:
      0.0
    case True{}:
      (((delta * ease_slope(e, p) : F32) * 1000.0 : F32) / duration : F32)

# Value at t ms after the start.
def curve_value(c: Curve, +target: F32, +from: F32, +v0: F32, +t: F32) -> F32:
  match c:
    case Tween{+duration, e}:
      +p = progress_of(t, duration)
      tween_value((p < 1.0 : F32), e, target, from, p)
    case Physics{s}:
      spring_value(s, target, (from - target : F32), v0, (t * 0.001 : F32))

def curve_velocity(c: Curve, +target: F32, +from: F32, +v0: F32, +t: F32) -> F32:
  match c:
    case Tween{+duration, e}:
      +p = progress_of(t, duration)
      tween_velocity((p < 1.0 : F32), e, (target - from : F32), duration, p)
    case Physics{s}:
      spring_velocity(s, (from - target : F32), v0, (t * 0.001 : F32))

def curve_done(c: Curve, +target: F32, +from: F32, +v0: F32, +t: F32) -> Bool:
  match c:
    case Tween{+duration, e}:
      Bool.not((progress_of(t, duration) < 1.0 : F32))
    case Physics{s}:
      spring_done(s, (from - target : F32), v0, (t * 0.001 : F32))

# Motion
# ------

# One animated number: heading for `target` under `curve`, having left
# `from` with velocity `v0` (units per second) at clock `start` (ms).
type Motion is Data:
  Motion{curve: Curve, target: F32, start: U32, from: F32, v0: F32}

# A motion at rest at `value`; it needs no frames until retargeted.
def rest(c: Curve, +value: F32) -> Motion:
  Motion{c, value, 0, value, 0.0}

# A motion from `from` at rest to `to`, starting at `now`.
def animate(c: Curve, now: U32, from: F32, to: F32) -> Motion:
  Motion{c, to, now, from, 0.0}

def target(m: Motion) -> F32:
  match m:
    case Motion{c, t, s, f, v}:
      t

def curve(m: Motion) -> Curve:
  match m:
    case Motion{c, t, s, f, v}:
      c

# The value at `now`. Before `start` it is `from`; once done, exactly
# `target`.
def value(m: Motion, +now: U32) -> F32:
  match m:
    case Motion{c, +target, +start, +from, +v0}:
      curve_value(c, target, from, v0, elapsed(now, start))

def velocity_at(go: Bool, c: Curve, +target: F32, +from: F32, +v0: F32, +t: F32) -> F32:
  match go:
    case False{}:
      v0
    case True{}:
      curve_velocity(c, target, from, v0, t)

# The velocity at `now`, in value units per second. Before `start` it is
# `v0`; once done, 0.
def velocity(m: Motion, +now: U32) -> F32:
  match m:
    case Motion{c, +target, +start, +from, +v0}:
      velocity_at(started(now, start), c, target, from, v0, elapsed(now, start))

def done_at(at_rest: Bool, go: Bool, c: Curve, +target: F32, +from: F32, +v0: F32, +t: F32) -> Bool:
  match at_rest go:
    case True{} _:
      True{}
    case False{} False{}:
      False{}
    case False{} True{}:
      curve_done(c, target, from, v0, t)

# True when the motion no longer changes. A motion that starts at its target
# with no velocity is done at any time, so a resting motion never wakes the
# host, whatever the clock reads.
def done(m: Motion, +now: U32) -> Bool:
  match m:
    case Motion{c, +target, +start, +from, +v0}:
      done_at((F32.is_eq(from, target) && F32.is_eq(v0, 0.0)), started(now, start), c, target, from, v0, elapsed(now, start))

def deadline_at(finished: Bool, go: Bool, +now: U32, start: U32, frame_ms: U32) -> Maybe<&2, U32>:
  match finished go:
    case True{} _:
      None{}
    case False{} False{}:
      Some{start}
    case False{} True{}:
      Some{(now + U32.max(frame_ms, 1) : U32)}

# When the host must draw again: None once done (no more frames), the start
# time while a delayed motion waits, else `now + frame_ms` (at least 1).
def next_deadline(+m: Motion, +now: U32, frame_ms: U32) -> Maybe<&2, U32>:
  match m:
    case Motion{c, t, +start, f, v}:
      deadline_at(done(m, now), started(now, start), now, start, frame_ms)

def retarget_if(go: Bool, +m: Motion, +now: U32, +to: F32) -> Motion:
  match go:
    case False{}:
      m
    case True{}:
      Motion{curve(m), to, now, value(m, now), velocity(m, now)}

# Heads for `to` from the current value AND velocity at `now`, so a reversal
# mid-flight has no jump (a spring keeps its momentum; a tween restarts its
# full duration from the current value). Retargeting to the current target,
# or to a non-finite number, changes nothing.
def retarget(+m: Motion, +now: U32, +to: F32) -> Motion:
  retarget_if(Bool.and(finite(to), Bool.not(F32.is_eq(to, target(m)))), m, now, to)

def settle_if(finished: Bool, +m: Motion, +now: U32) -> Motion:
  match finished:
    case False{}:
      m
    case True{}:
      rest(curve(m), target(m))

# Once done, collapses the motion to `rest` at its target. Optional: it keeps
# a long-idle motion independent of the clock (see `elapsed`).
def settle(+m: Motion, +now: U32) -> Motion:
  settle_if(done(m, now), m, now)

# Reduce-motion for one motion: jumps to the target at once, keeping the
# curve for later retargets.
def reduced(m: Motion) -> Motion:
  match m:
    case Motion{c, +target, start, from, v0}:
      Motion{c, target, start, target, 0.0}
