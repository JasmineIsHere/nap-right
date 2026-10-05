# SensorProbe test contract

These are Code-phase success criteria derived from the approved M0 SensorProbe scope. This task
adds tests and their simulator harness only. No sleep detector, physiological thresholds or
production probe implementation is authorized by this test-only step.

## Test boundary

`new ProbeFactory().create(options, platform)` will construct the real probe session. Options supply
`recordCapacity`, `rrCapacity` and `alarmDelayMs`; tests use small capacities to exercise limits.
The future watch app supplies a platform adapter; tests supply a fake only for hardware side
effects. The session owns sensor capture, bounded diagnostic records, RMSSD and alarm lifecycle.

The interface required by these tests is:

- `start(elapsedMs, wallSeconds)` returns true on success, false on startup failure; duplicate
  starts do not restart sensors or timers or move the existing deadline.
- `heartRate(elapsedMs, wallSeconds, bpmOrNull)` records valid positive numeric bpm unchanged.
  Null denotes unavailable data; nonnumeric and nonpositive values are rejected explicitly.
- `accelerometer(elapsedMs, wallSeconds, payloadOrNull)` accepts SDK-shaped `x`, `y`, `z`,
  `timestamp` arrays. Axes are in millig and native sample timestamps in milliseconds. Capture
  callback elapsed and wall timestamps separately from native timestamps. Reject unequal array
  lengths, missing axes, nonnumeric components and mismatched timestamp lengths; do not fabricate XYZ data.
  A null timestamp array is allowed and preserved as null. Empty arrays contain no samples.
- `rr(elapsedMs, wallSeconds, intervalsOrNull)` accepts positive numeric milliseconds. Null
  denotes an unavailable callback, not a count of missing beats. Invalid intervals and unavailable
  callbacks break the consecutive RR segment. Experimental RMSSD uses only the latest contiguous
  valid segment, bounded by `rrCapacity`, and is null with fewer than two intervals. Never bridge
  a gap. This is an M0 diagnostic definition, not the future detector's HRV gate.
- `tick(elapsedMs, wallSeconds)` triggers one alarm at or after the start-relative configured
  deadline; delayed delivery records scheduled and actual elapsed timestamps. Wall-clock changes
  do not change the deadline. Repeated ticks never vibrate again.
- `stop(elapsedMs, wallSeconds, reason)` cleans up sensors and timer once and records the
  supplied reason. Late ticks/sensor callbacks cannot revive a stopped session.
- `snapshot()` returns `records`, `stats`, `rmssdMs`, `rrCount`, `running`, `deadlineMs`.
  Records are chronological and bounded by `recordCapacity`; oldest records are evicted and
  `droppedRecords` increases. Drain and snapshots must not expose mutable internal records.
- `drain()` returns queued records and clears that queue without resetting lifetime counters or
  RR history. This enables incremental logging; it does not prove a physical export implementation.

Options in the tests are positive integers with `recordCapacity >= 1`, `rrCapacity >= 2`,
`alarmDelayMs >= 1`. Invalid options must throw before any platform side effect. The default
20-minute nap behavior belongs to the later nap lifecycle; M0 alarm tests configure their own
deadlines, including a long-duration case.

Platform boundary: `startSensors()`, `startTimer()`, `stopSensors()`, `stopTimer()`, and
`vibrate()`. Starts may throw. Startup failures return false, stop attempted resources and
record a `sensor_error` or `timer_error`; a subsequent stop is idempotent. No tests mock the
probe's own behavior.

## Record and counter expectations

Each record contains `kind`, `elapsedMs`, `wallSeconds`. Signal records also contain a `unit`
and `value`: HR `bpm`, XYZ `millig` with `[x,y,z]` plus `sampleTimestampMs`, RR `ms`.
Missing/rejected records use `value: null`, `quality: missing` or `quality: rejected` and a reason;
valid signal records use `quality: valid`. Lifecycle records are `started`, `alarm`, `stopped`,
`sensor_error`, `timer_error`. An alarm adds `scheduledMs` and `actualMs`; stopped adds `reason`.

`stats` uses these counters: `hrSamples`, `hrMissing`, `hrRejected`, `accelSamples`, `accelMissing`,
`accelRejected`, `rrSamples`, `rrMissingCallbacks`, `rrRejected`, `droppedRecords`.
Counters are lifetime counts independent of record eviction/drain. Malformed acceleration
batches increment `accelRejected` once and accept no samples. An invalid individual vector in
an otherwise well-shaped batch increments it once; valid vectors remain eligible. RR rejection
counts invalid intervals individually. Records and RR storage must remain bounded even with
large batches or long simulated sessions.

Timestamp inputs are caller-provided capture time; they are not an inferred physiological onset.
These tests use monotonic elapsed inputs. Verifying platform clock wrap, timestamp origin, sample
ordering and display behavior remains physical/API adapter work and must precede M0 approval.

## Deterministic cases

| Area          | Required cases and independent expectations                                                                                                              |
| ------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------- |
| HR            | Positive value and exact units/times; null versus zero; rejected string; cumulative counters                                                             |
| Motion        | Exact axes and native times; no timestamps preserved as null; malformed batch; invalid vector; empty/missing batches                                     |
| RR            | `[800,900,800]` gives 100 ms; `[800,800,800]` gives 0; one interval gives null; invalid/gap prevents bridging; capacity window changes result            |
| Records       | Capacity three retains last three records, exact eviction count; drain preserves counters/history; snapshot/drain mutation does not alter internal state |
| Alarm         | Before/exact deadline; delayed callback; repeated callback; cancellation; wall-clock jump; 66-minute simulated deadline                                  |
| Lifecycle     | Duplicate start; stop twice; callbacks after stop; sensor registration failure; timer startup failure                                                    |
| Configuration | Zero/negative/missing required capacities or delay rejected before side effects                                                                          |
| Long run      | Repeated small batches and a batch larger than capacity retain only the bounded recent records and RR window                                             |

## Red-stage harness and validation

The test harness is a simulator-only application with no real sensor registration. A generated, ignored
`red.jungle` includes an empty `ProbeFactory` class so tests compile before production exists.
The test helper checks for the missing factory, logs `M0_RED: ProbeFactory.create is not implemented`
and returns failure. It never supplies a fake probe or computes expected results.
The red-only `ProbeSignatureMarkers` declares the future method names for MonkeyC symbol
resolution. It is never constructed; every method throws rather than supplying behavior.

Generated normal `tests.jungle` includes the real `source/` directory and excludes that empty class.
After implementation, use normal tests; red-stage execution is not evidence that behavior passes.
Both test builds use `-l 0` to permit dynamic factory invocation and deliberate invalid-input
cases. This does not disable syntax or undefined-symbol checks. Production compilation is separate.
All test names must appear exactly once, with zero unexpected errors. The current expected red
result is failures for missing implementation, not SDK setup or compiler syntax errors.

Format all changed code first, build with SDK 9.2.0 for `vivoactive5`, run the complete simulator
suite and inspect its named results and summary. As established during preparation, `monkeydo`
returns 1 even for a passing run; do not infer results from its exit code alone.

Independent review must assess coverage, false positives/negatives, numeric expectations,
hardware-double boundaries, all changed test/harness files and actual compiler/simulator output.
Resolve findings before any production implementation. Leave tests uncommitted while deliberately
red: repository instructions require passing required tests and final approval before commit.

## Physical acceptance still required

Visible/dim/off runs, wrist removal, actual nap attempt, interruptions, >=45-minute and roughly
65–66-minute runs, actual haptic delivery/error, battery <=8%/hour under recorded conditions,
heap/storage limits and watch-generated diagnostic extraction remain M0 hardware gates. Simulator
timestamps, fake platform side effects and record drain cannot satisfy those gates.
