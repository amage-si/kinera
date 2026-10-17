# Contributing to Kinera

Use Bend 2.0.37 for the current baseline. Read `bend guide` before editing Bend
and keep project text in English. Library implementation belongs in Bend; the
official runtime and operating system remain external dependencies.

## Validation

From the repository root:

```sh
export BEND_NO_TELEMETRY=1
mkdir -p build
bend main.bend --check-only
bend tests.bend -o build/tests
./build/tests --threads 2 --gpu off
bend examples/hover.bend -o build/hover
./build/hover --threads 2 --gpu off
```

Inside the AMAGE Eco workspace, run every compile under the shared build lock,
or let the build tool take it:

```sh
flock /tmp/amage-eco-bend-build.lock nice -n 10 bend tests.bend -o build/tests
cd ../build && ./eco test kinera-tests
```

The tests need no display. The reference values in `tests.bend` come from a
float64 Python model of the same formulas (Bezier curves solved by bisection
to machine precision; springs from the closed forms in
[docs/api.md](docs/api.md)). When behavior changes, recompute them with an
independent script and keep the stated tolerances: 1e-4 absolute for easing,
1e-4 relative (floored at one unit) for spring position and velocity.

## Measuring cost

```sh
bend examples/bench.bend -o build/bench
flock -n /tmp/amage-eco-bench.lock ./build/bench --threads 2 --gpu off
```

Take the bench lock while timing and run nothing else heavy. Report the
per-call cost before and after any change to `value()`, `velocity()` or
`done()`.

Build one target at a time. The native Bend runtime reserves substantial virtual
address space; a virtual-memory limit is not a resident-memory limit. Preserve
crash evidence and investigate before repeating a failed compiler invocation.

## Changes

Keep the API small and the units explicit. Add a focused regression check when
behavior changes, update [docs/api.md](docs/api.md) and the CHANGELOG, and
report what was actually validated. A claim about performance needs a
measurement; a claim about accuracy needs a reference.

Use English commit messages that explain the result. Do not commit `build/`,
generated C, logs, crash dumps, credentials, or machine-specific paths. Do not
publish BendHub packages or create releases as a side effect of validation.
