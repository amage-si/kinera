import Base
import ../main.bend as K

# Cost per call of value(), velocity() and done(): one million calls each,
# over 1000 distinct clock values, against an empty loop as the baseline.
# Run it alone, with the Eco bench lock held (see CONTRIBUTING.md).

type Op is Data:
  Idle{}
  AtValue{}
  AtVelocity{}
  IsDone{}

def call(op: Op, +m: K.Motion, +now: U32) -> F32:
  match op:
    case Idle{}:
      U32.to_f32(now)
    case AtValue{}:
      K.value(m, now)
    case AtVelocity{}:
      K.velocity(m, now)
    case IsDone{}:
      Bool.pick(F32, K.done(m, now), 1.0, 0.0)

def inner(n: Nat, +op: Op, +m: K.Motion, +now: U32, acc: F32) -> F32:
  match n:
    case 0n:
      acc
    case 1n+k:
      inner(k, op, m, (now + 1 : U32), (acc + call(op, m, now) : F32))

# `zero` is 0 computed from the clock, so the loop cannot run before it.
def outer(n: Nat, +op: Op, +m: K.Motion, +zero: U32, acc: F32) -> F32:
  match n:
    case 0n:
      acc
    case 1n+k:
      outer(k, op, m, zero, inner(1000n, op, m, (1000 + zero : U32), acc))

def measure(+name: String, op: Op, m: K.Motion) -> IO(Unit):
  do IO<Unit>:
    +t0 : Nat <- IO.now()
    +sum : F32 <- IO.pure(F32, outer(1000n, op, m, U32.mul(U32.from_nat(t0), 0), 0.0))
    IO.print("  checksum " ++ F32.show(sum))
    +t1 : Nat <- IO.now()
    IO.print(name ++ ": 1000000 calls in " ++ Nat.show(Nat.sub(t1, t0)) ++ " ms")

def main() -> IO(Unit):
  do IO<Unit>:
    measure("empty loop", Idle{}, K.animate(K.spring(K.bouncy()), 1000, 0.0, 100.0))
    measure("value, bouncy spring", AtValue{}, K.animate(K.spring(K.bouncy()), 1000, 0.0, 100.0))
    measure("value, smooth spring", AtValue{}, K.animate(K.spring(K.smooth()), 1000, 0.0, 100.0))
    measure("value, overdamped spring", AtValue{}, K.animate(K.spring(K.physical(100.0, 40.0, 1.0)), 1000, 0.0, 100.0))
    measure("value, ease-in-out tween", AtValue{}, K.animate(K.tween(1000.0, K.ease_in_out()), 1000, 0.0, 100.0))
    measure("value, linear tween", AtValue{}, K.animate(K.tween(1000.0, K.linear()), 1000, 0.0, 100.0))
    measure("velocity, bouncy spring", AtVelocity{}, K.animate(K.spring(K.bouncy()), 1000, 0.0, 100.0))
    measure("done, bouncy spring", IsDone{}, K.animate(K.spring(K.bouncy()), 1000, 0.0, 100.0))
