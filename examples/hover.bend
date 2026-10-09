import Base
import ../main.bend as K

# A hover highlight driven the way a host drives it: the pointer enters at
# 0 ms (opacity heads to 1), leaves at 120 ms (heads back to 0), and the host
# draws frames on a 120 Hz grid until next_deadline says no more frames.

def show(+now: U32, +m: K.Motion) -> String:
  "  t=" ++ U32.show(now) ++ " ms  opacity=" ++ F32.show(K.value(m, now)) ++ "  velocity=" ++ F32.show(K.velocity(m, now)) ++ "/s"

# The pointer leaves at 120 ms.
def leave_at(+now: U32, +m: K.Motion) -> K.Motion:
  Bool.pick(K.Motion, U32.is_eq(now, 120), K.retarget(m, now, 0.0), m)

# Draws the frame at `now`, then follows the motion's next deadline.
def run(fuel: Nat, next: Maybe<&2, U32>, +frame: U32, +now: U32, +m: K.Motion, +drawn: U32) -> IO(Unit):
  match fuel next:
    case 0n _:
      IO.print("out of fuel")
    case 1n+k None{}:
      IO.print(show(now, m) ++ "\nidle after " ++ U32.show(drawn) ++ " frames: no more frames needed")
    case 1n+k Some{+t}:
      +moved = leave_at(t, m)
      do IO<Unit>:
        IO.print(show(now, m))
        run(k, K.next_deadline(moved, t, frame), frame, t, moved, (drawn + 1 : U32))

def main() -> IO(Unit):
  +m = K.retarget(K.rest(K.spring(K.snappy()), 0.0), 0, 1.0)
  run(400n, K.next_deadline(m, 0, 8), 8, 0, m, 1)
