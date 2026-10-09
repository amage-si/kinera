import Base
import ./main.bend as K

# Reference values come from a float64 Python model of the same formulas
# (bisection to 1e-15 for the Bezier curves); see CONTRIBUTING.md.

def expect(ok: Bool, name: String) -> IO(Unit):
  match ok:
    case False{}:
      IO.die(Unit, 1, "FAIL: " ++ name)
    case True{}:
      IO.print("PASS: " ++ name)

def near(a: F32, b: F32, tol: F32) -> Bool:
  (F32.abs((a - b : F32)) <= tol : F32)

# Worst |ease(p) - ref| over the five sample points 0.1 .. 0.9.
def ease_err(+e: K.Ease, ps: List<F32>, refs: List<F32>, worst: F32) -> F32:
  match ps refs:
    case Con{p, pt} Con{r, rt}:
      ease_err(e, pt, rt, F32.max(worst, F32.abs((K.ease_at(e, p) - r : F32))))
    case _ _:
      worst

def samples() -> List<F32>:
  [0.1, 0.25, 0.5, 0.75, 0.9]

def show_err(+name: String, err: F32) -> IO(Unit):
  IO.print("  " ++ name ++ " max error " ++ F32.show(err))

def ease_case(+name: String, e: K.Ease, refs: List<F32>) -> IO(Unit):
  +err = ease_err(e, samples(), refs, 0.0)
  do IO<Unit>:
    show_err(name, err)
    expect((err <= 0.0001 : F32), name ++ " matches the reference within 1e-4")

# One reference sample: ms after the start, value, velocity (units/s).
type Row is Data:
  Row{ms: U32, x: F32, v: F32}

# Relative error, floored at 1 unit: |a - b| / max(1, |b|).
def rel(a: F32, +b: F32) -> F32:
  (F32.abs((a - b : F32)) / F32.max(1.0, F32.abs(b)) : F32)

def row_err(+m: K.Motion, rows: List<Row>, worst: F32) -> F32:
  match rows:
    case Nil{}:
      worst
    case Con{Row{+ms, x, v}, rest}:
      +now = (1000 + ms : U32)
      row_err(m, rest, F32.max(worst, F32.max(rel(K.value(m, now), x), rel(K.velocity(m, now), v))))

def spring_case(+name: String, s: K.Spring, v0: F32, rows: List<Row>) -> IO(Unit):
  +err = row_err(K.Motion{K.spring(s), 100.0, 1000, 0.0, v0}, rows, 0.0)
  do IO<Unit>:
    show_err(name, err)
    expect((err <= 0.0001 : F32), name ++ " position and velocity match the closed-form reference")

# The first ms (from 1000) when a 0 -> 1 motion is done must be `at`.
def settles_at(s: K.Spring, +at: U32) -> Bool:
  +m = K.animate(K.spring(s), 1000, 0.0, 1.0)
  Bool.not(K.done(m, (999 + at : U32))) && K.done(m, (1000 + at : U32))

def is_some(found: Maybe<&2, U32>, want: U32) -> Bool:
  match found:
    case None{}:
      False{}
    case Some{t}:
      U32.is_eq(t, want)

def is_none(found: Maybe<&2, U32>) -> Bool:
  match found:
    case None{}:
      True{}
    case Some{t}:
      False{}

# Re-anchors a motion at `now` from its current value and velocity, as a
# host that rebuilt it every frame would.
def rebase(+m: K.Motion, +now: U32) -> K.Motion:
  K.Motion{K.curve(m), K.target(m), now, K.value(m, now), K.velocity(m, now)}

# Steps `n` frames of `frame` ms each, re-anchoring every frame.
def frames(n: Nat, +frame: U32, +now: U32, m: K.Motion) -> K.Motion:
  match n:
    case 0n:
      m
    case 1n+k:
      frames(k, frame, (now + frame : U32), rebase(m, (now + frame : U32)))

def bouncy_trip() -> K.Motion:
  K.animate(K.spring(K.bouncy()), 1000, 0.0, 100.0)

# |stepped - direct| after 300 ms, re-anchored every `frame` ms.
def stepped_err(n: Nat, frame: U32) -> F32:
  +m = frames(n, frame, 1000, bouncy_trip())
  F32.max(F32.abs((K.value(m, 1300) - K.value(bouncy_trip(), 1300) : F32)), (F32.abs((K.velocity(m, 1300) - K.velocity(bouncy_trip(), 1300) : F32)) / 100.0 : F32))

def start_of(m: K.Motion) -> U32:
  match m:
    case K.Motion{c, t, s, f, v}:
      s

# True when the motion is done at every ms of [now, now + n).
def stays_done(n: Nat, +m: K.Motion, +now: U32) -> Bool:
  match n:
    case 0n:
      True{}
    case 1n+k:
      Bool.and(K.done(m, now), stays_done(k, m, (now + 1 : U32)))

def hover() -> K.Motion:
  K.retarget(bouncy_trip(), 1120, 0.0)

def main() -> IO(Unit):
  do IO<Unit>:
    IO.print("Easing against the Python reference")
    ease_case("ease", K.ease(), [0.094796, 0.408511, 0.802403, 0.960459, 0.994316])
    ease_case("ease-in", K.ease_in(), [0.017027, 0.093465, 0.315357, 0.621862, 0.839428])
    ease_case("ease-out", K.ease_out(), [0.160572, 0.378138, 0.684643, 0.906535, 0.982973])
    ease_case("ease-in-out", K.ease_in_out(), [0.019722, 0.129162, 0.5, 0.870838, 0.980278])
    ease_case("cubic-bezier(0.68, -0.6, 0.32, 1.6)", K.cubic_bezier(0.68, F32.neg(0.6), 0.32, 1.6), [F32.neg(0.072823), F32.neg(0.097708), 0.5, 1.097708, 1.072823])
    ease_case("cubic-bezier(1, 0, 0, 1)", K.cubic_bezier(1.0, 0.0, 0.0, 1.0), [0.003762, 0.029725, 0.499997, 0.970275, 0.996238])
    expect(F32.is_eq(K.ease_at(K.ease_in_out(), 0.0), 0.0) && F32.is_eq(K.ease_at(K.ease_in_out(), 1.0), 1.0), "easing ends are exact")
    expect(F32.is_eq(K.ease_at(K.ease(), F32.neg(1.0)), 0.0) && F32.is_eq(K.ease_at(K.ease(), 1.5), 1.0) && F32.is_eq(K.ease_at(K.ease(), F32.div(0.0, 0.0)), 0.0), "progress outside [0, 1] or NaN is clamped")
    expect(near(K.ease_at(K.cubic_bezier(F32.div(0.0, 0.0), 0.0, 1.0, 1.0), 0.3), 0.3, 0.000001), "NaN bezier parameter yields linear")
    expect(near(K.ease_at(K.cubic_bezier(2.0, 0.0, F32.neg(1.0), 1.0), 0.3), K.ease_at(K.cubic_bezier(1.0, 0.0, 0.0, 1.0), 0.3), 0.000001), "bezier x outside [0, 1] is clamped")
    IO.print("Springs against the closed-form reference (0 -> 100)")
    spring_case("smooth", K.smooth(), 0.0, [Row{0, 0.0, 0.0}, Row{50, 13.1311, 421.2253}, Row{100, 35.774, 449.4374}, Row{200, 71.5416, 255.8283}, Row{400, 96.0457, 41.4455}, Row{800, 99.9524, 0.5439}])
    spring_case("smooth, v0 -300", K.smooth(), F32.neg(300.0), [Row{0, 0.0, F32.neg(300.0)}, Row{50, 5.1288, 361.739}, Row{100, 27.2357, 471.3498}, Row{200, 66.6814, 292.6021}, Row{400, 95.2584, 49.3715}, Row{800, 99.9421, 0.6608}])
    spring_case("snappy", K.snappy(), 0.0, [Row{0, 0.0, 0.0}, Row{50, 13.821, 454.4508}, Row{100, 38.8102, 503.8908}, Row{200, 78.6369, 273.1708}, Row{400, 100.1617, 15.7651}, Row{800, 100.0155, F32.neg(0.3872)}])
    spring_case("snappy, v0 -300", K.snappy(), F32.neg(300.0), [Row{0, 0.0, F32.neg(300.0)}, Row{50, 5.1875, 380.3506}, Row{100, 29.2375, 524.8231}, Row{200, 73.4473, 319.9466}, Row{400, 99.8622, 22.6484}, Row{800, 100.0228, F32.neg(0.4979)}])
    spring_case("bouncy", K.bouncy(), 0.0, [Row{0, 0.0, 0.0}, Row{50, 14.5715, 491.7049}, Row{100, 42.3302, 570.7558}, Row{200, 87.3711, 295.3807}, Row{400, 103.9303, F32.neg(22.5969)}, Row{800, 99.8779, 1.2074}])
    spring_case("bouncy, v0 -300", K.bouncy(), F32.neg(300.0), [Row{0, 0.0, F32.neg(300.0)}, Row{50, 5.2302, 399.7596}, Row{100, 31.4872, 588.5076}, Row{200, 81.7595, 356.2177}, Row{400, 104.3596, F32.neg(18.3585)}, Row{800, 99.8549, 1.2445}])
    spring_case("overdamped k100 c40 m1", K.physical(100.0, 40.0, 1.0), 0.0, [Row{0, 0.0, 0.0}, Row{50, 6.9705, 207.81}, Row{100, 17.7737, 213.9091}, Row{200, 36.964, 168.7508}, Row{400, 63.1123, 98.8402}, Row{800, 87.3699, 33.8422}])
    spring_case("overdamped, v0 -300", K.physical(100.0, 40.0, 1.0), F32.neg(300.0), [Row{0, 0.0, F32.neg(300.0)}, Row{50, 0.7362, 178.0935}, Row{100, 11.3564, 223.9211}, Row{200, 31.9015, 182.1438}, Row{400, 60.1471, 106.7853}, Row{800, 86.3547, 36.5626}])
    expect(settles_at(K.smooth(), 782), "smooth settles at 782 ms (0 -> 1)")
    expect(settles_at(K.snappy(), 746), "snappy settles at 746 ms (0 -> 1)")
    expect(settles_at(K.bouncy(), 873), "bouncy settles at 873 ms (0 -> 1)")
    expect(settles_at(K.physical(100.0, 40.0, 1.0), 2619), "overdamped settles at 2619 ms (0 -> 1)")
    expect(stays_done(3000n, K.animate(K.spring(K.bouncy()), 1000, 0.0, 1.0), 1873) && stays_done(3000n, K.animate(K.spring(K.physical(100.0, 40.0, 1.0)), 1000, 0.0, 1.0), 3619), "once settled, a spring stays done (checked every ms for 3 s)")
    expect(near(K.velocity(K.animate(K.tween(200.0, K.linear()), 1000, 0.0, 100.0), 1050), 500.0, 0.01) && near(K.velocity(K.animate(K.tween(200.0, K.ease_in_out()), 1000, 0.0, 100.0), 1100), 862.06897, 0.05), "tween velocity in units per second")
    expect(F32.is_eq(K.value(K.animate(K.spring(K.bouncy()), 1000, 0.0, 1.0), 1873), 1.0) && F32.is_eq(K.velocity(K.animate(K.spring(K.bouncy()), 1000, 0.0, 1.0), 1873), 0.0), "a settled spring reads exactly its target, at rest")
    IO.print("Interruption")
    expect(near(K.value(hover(), 1120), K.value(bouncy_trip(), 1120), 0.0001) && near(K.velocity(hover(), 1120), K.velocity(bouncy_trip(), 1120), 0.01), "spring retarget keeps value and velocity")
    expect(near(K.value(hover(), 1121), (K.value(bouncy_trip(), 1120) + (K.velocity(bouncy_trip(), 1120) * 0.001 : F32) : F32), 0.05), "spring reversal has no jump 1 ms later")
    expect(near(K.value(hover(), 1520), F32.neg(2.873012), 0.001) && near(K.value(hover(), 1220), 50.322993, 0.001), "reversed spring keeps its momentum, then heads to the new target")
    expect(near(K.value(K.retarget(K.animate(K.tween(200.0, K.ease_in_out()), 1000, 0.0, 100.0), 1080, 0.0), 1080), K.value(K.animate(K.tween(200.0, K.ease_in_out()), 1000, 0.0, 100.0), 1080), 0.0001), "tween retarget starts from the current value")
    expect(U32.is_eq(start_of(K.retarget(bouncy_trip(), 1120, 100.0)), 1000), "retarget to the same target changes nothing")
    expect(U32.is_eq(start_of(K.retarget(bouncy_trip(), 1120, F32.div(0.0, 0.0))), 1000), "retarget to NaN changes nothing")
    IO.print("Frame-rate independence (bouncy, 300 ms, re-anchored every frame)")
    show_err("60 Hz (17 ms frames)", stepped_err(17n, 17))
    show_err("120 Hz (8 ms frames)", stepped_err(37n, 8))
    show_err("1 kHz (1 ms frames)", stepped_err(300n, 1))
    expect((stepped_err(17n, 17) < 0.001 : F32) && (stepped_err(37n, 8) < 0.001 : F32) && (stepped_err(300n, 1) < 0.001 : F32), "frame sequences equal direct evaluation")
    IO.print("Done and next deadline")
    expect(is_some(K.next_deadline(bouncy_trip(), 1100, 8), 1108), "a moving motion asks for the next frame")
    expect(is_none(K.next_deadline(K.animate(K.spring(K.smooth()), 1000, 0.0, 1.0), 1782, 8)), "a settled spring asks for no more frames")
    expect(Bool.not(K.done(K.animate(K.tween(200.0, K.ease()), 1000, 0.0, 1.0), 1199)) && K.done(K.animate(K.tween(200.0, K.ease()), 1000, 0.0, 1.0), 1200), "a tween is done exactly at its duration")
    expect(F32.is_eq(K.value(K.animate(K.tween(200.0, K.ease()), 1000, 0.0, 7.5), 1200), 7.5), "a finished tween reads exactly its target")
    expect(is_none(K.next_deadline(K.animate(K.tween(200.0, K.ease()), 1000, 0.0, 1.0), 1200, 8)), "a finished tween asks for no more frames")
    expect(is_some(K.next_deadline(K.animate(K.tween(200.0, K.ease()), 2000, 0.0, 1.0), 1500, 8), 2000), "a delayed motion asks for its start")
    expect(is_none(K.next_deadline(K.rest(K.spring(K.bouncy()), 3.0), 4000000000, 8)) && F32.is_eq(K.value(K.rest(K.spring(K.bouncy()), 3.0), 77), 3.0), "a motion at rest needs no frames at any time")
    expect(is_some(K.next_deadline(bouncy_trip(), 1100, 0), 1101), "a zero frame interval counts as 1 ms")
    expect(is_none(K.next_deadline(K.settle(K.animate(K.spring(K.smooth()), 1000, 0.0, 1.0), 1782), 5000000, 8)) && F32.is_eq(K.value(K.settle(K.animate(K.spring(K.smooth()), 1000, 0.0, 1.0), 1782), 0), 1.0), "settle collapses a done motion to rest")
    IO.print("Reduce motion")
    expect(F32.is_eq(K.value(K.reduced(bouncy_trip()), 1001), 100.0) && K.done(K.reduced(bouncy_trip()), 1001) && is_none(K.next_deadline(K.reduced(bouncy_trip()), 1001, 8)), "reduced jumps to the target and stops")
    expect(F32.is_eq(K.value(K.retarget(K.rest(K.honour(True{}, K.spring(K.bouncy())), 0.0), 1000, 1.0), 1000), 1.0) && K.done(K.retarget(K.rest(K.honour(True{}, K.spring(K.bouncy())), 0.0), 1000, 1.0), 1000), "honour(True) makes every retarget instant")
    expect(near(K.value(K.retarget(K.rest(K.honour(False{}, K.spring(K.bouncy())), 0.0), 1000, 1.0), 1100), 0.423302, 0.0001), "honour(False) keeps the curve")
    IO.print("Edge cases")
    expect(F32.is_eq(K.value(K.animate(K.tween(0.0, K.ease()), 1000, 0.0, 5.0), 1000), 5.0) && K.done(K.animate(K.tween(0.0, K.ease()), 1000, 0.0, 5.0), 1000), "zero duration lands at its start")
    expect(F32.is_eq(K.value(K.animate(K.tween(F32.div(0.0, 0.0), K.ease()), 1000, 0.0, 5.0), 1000), 5.0) && F32.is_eq(K.value(K.animate(K.tween(F32.neg(50.0), K.ease()), 1000, 0.0, 5.0), 1000), 5.0), "NaN and negative durations become zero")
    expect(F32.is_eq(K.value(bouncy_trip(), 900), 0.0) && F32.is_eq(K.velocity(K.Motion{K.spring(K.bouncy()), 1.0, 1000, 0.0, 4.0}, 900), 4.0) && Bool.not(K.done(bouncy_trip(), 900)), "before its start a motion holds its start state")
    expect(near(K.value(K.animate(K.spring(K.bouncy()), 4294967000, 0.0, 100.0), 104), 103.9303, 0.001), "the U32 clock may wrap mid-motion")
    expect(near(K.value(K.animate(K.spring(K.physical(100.0, 40.0, 0.0)), 1000, 0.0, 100.0), 1200), 36.964, 0.001) && near(K.value(K.animate(K.spring(K.physical(F32.neg(5.0), 40.0, 1.0)), 1000, 0.0, 100.0), 1100), K.value(K.animate(K.spring(K.responsive(500.0, 1.5915494)), 1000, 0.0, 100.0), 1100), 0.001), "zero mass and negative stiffness fall back to defaults")
    expect(near(K.value(K.animate(K.spring(K.responsive(F32.neg(1.0), F32.div(0.0, 0.0))), 1000, 0.0, 100.0), 1200), 71.5416, 0.001), "negative response and NaN ratio fall back to smooth")
    expect(K.done(K.animate(K.spring(K.responsive(500.0, 0.0)), 1000, 0.0, 1.0), 121000) && K.done(K.animate(K.spring(K.physical(100.0, F32.neg(3.0), 1.0)), 1000, 0.0, 1.0), 121000), "zero or negative damping still settles")
    expect(F32.is_eq(K.clamp(F32.div(0.0, 0.0), 0.0, 1.0), 0.0) && F32.is_eq(K.lerp(2.0, 4.0, 0.25), 2.5) && F32.is_eq(K.progress(1050, 1000, 100.0), 0.5) && F32.is_eq(K.progress(900, 1000, 100.0), 0.0) && F32.is_eq(K.progress(1000, 1000, 0.0), 1.0), "lerp, clamp and progress")
    IO.print("Kinera: 52 tests passed")
