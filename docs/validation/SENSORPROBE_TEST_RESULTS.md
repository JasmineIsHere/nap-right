# SensorProbe test preparation evidence

Date: 2026-10-05. Scope: deterministic session tests and simulator harness only.

## Gate checklist

- [x] Approved M0 roadmap and refined test contract reviewed before test authoring.
- [x] Measurable criteria recorded in `SENSORPROBE_TEST_CONTRACT.md`.
- [x] Required tools verified: Connect IQ SDK 9.2.0, Java, vívoactive 5 device package,
      simulator, local signing key, and configured Prettier plugins.
- [x] Tests authored before production implementation: 45 cases across capture, RMSSD,
      bounded records, configuration and alarm/resource lifecycle.
- [x] Formatting: `npm run format`, then `npm run format:check`; both succeeded.
- [x] Red harness compiled successfully with no warnings.
- [x] Simulator discovered all 45 tests exactly once: 0 passed, 45 failed, 0 errors.
      Every failure logged the missing `ProbeFactory.create` implementation marker.
- [x] Independent test-suite approval after correcting the review finding below.
- [ ] Production implementation and passing behavioral assertions.
- [ ] Physical M0 acceptance, including actual sensor availability, haptic delivery,
      display states, long sessions, battery, heap/storage and diagnostic extraction.
- [ ] Fresh final code review, explicit approval and commit after required tests pass.

The previously approved contract review reported no findings. It approved the factory boundary
and red-only harness approach, not these subsequently authored assertions. The current independent
review covered the full test suite. It found that invalid-configuration tests omitted assertions
for sensor/timer cleanup side effects. Both zero-counter assertions were added; formatting,
compilation and the complete red run were repeated with the same results. The reviewer inspected
the correction, reported `No findings.`, and explicitly approved the suite for implementation.
No production code was added and no test changes were committed.

## Reproducing the current red run

Ignored `.local/probe-tests/red.jungle` uses the test manifest and resource directory, and source
directories `probe/tests/cases`, `probe/tests/support`, and `probe/tests/red`. Paths in the
descriptor are relative to its own directory. The normal `tests.jungle` replaces the red directory
with `probe/source`; use that configuration after implementation.

From the repository root:

```sh
sdk_path=$(cat '/Users/jasminetan/Library/Application Support/Garmin/ConnectIQ/current-sdk.cfg')
"$sdk_path/bin/monkeyc" -f .local/probe-tests/red.jungle \
  -d vivoactive5 -y .local/keys/developer_key.der \
  -o .local/probe-tests/SensorProbe-tests.prg -t -l 0 -w
"$sdk_path/bin/monkeydo" .local/probe-tests/SensorProbe-tests.prg vivoactive5 -t
```

Actual output is retained locally in `.local/evidence/sensorprobe-tests-build.log` and
`.local/evidence/sensorprobe-tests-red.log`. The compiler reported `BUILD SUCCESSFUL`.
The simulator reported `FAILED (passed=0, failed=45, errors=0)`.
An independent name comparison verified every source test appeared exactly once and counted
45 missing-implementation markers. `monkeydo` returns exit status 1 even for passing runs in
this installation; named results and the summary determine the result.

The missing-factory guard prevents behavioral assertions from executing in this red run.
This proves test discovery and a usable harness, not correctness of future implementation or
the ability of every assertion to detect a faulty implementation. Green execution and review
remain required. Simulated elapsed time and hardware doubles cannot establish watch feasibility.
