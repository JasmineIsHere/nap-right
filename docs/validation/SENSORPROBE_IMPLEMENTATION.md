# SensorProbe session implementation

The user authorized implementation after independent approval of the test suite.
The implementation follows `SENSORPROBE_TEST_CONTRACT.md`: it captures supplied HR/XYZ/RR
values and timestamps, maintains bounded records and a contiguous RR window, calculates
experimental RMSSD, and controls a single start-relative alarm and resource lifecycle.

This is the platform-independent session core. It requires a future Garmin sensor/timer/haptic
adapter and watch application. It does not infer sleep onset or constitute completed M0 hardware
preparation. The original roadmap's physical acceptance gates remain pending.

## Gates and evidence

- [x] Explore and plan: previously approved M0 roadmap and refined factory contract.
- [x] Required tools verified during preparation: SDK 9.2.0, device package, simulator,
      Java, signing key and Prettier. Preparation commit: `2c1c196`.
- [x] Test-first: 45 reviewed cases ran red before implementation; all failed for missing factory.
- [x] Implementation on feature branch `codex/sensorprobe-core`.
- [x] `npm run format` and `npm run format:check` succeeded.
- [x] Normal simulator build excludes all red-only sources: `BUILD SUCCESSFUL`, no warnings.
- [x] Complete suite: `PASSED (passed=45, failed=0, errors=0)`.
      Source-name comparison confirmed every case passed exactly once, with no red guard.
- [x] Test compatibility corrections independently re-reviewed: no findings, explicit approval.
- [x] Fresh independent final code review: no findings; explicit approval for core commit.
- [ ] Commit after approval; record hash in the task.
- [ ] Garmin adapter, watch app and physical M0 acceptance.

The final reviewer independently inspected all 15 changed files, the source contract, original
roadmap and logs, and verified formatting, staged whitespace checks and all 45 unique passes.
Residual unit-test gaps noted: throwing cleanup methods, restart after stop/failure, and mutation
of caller-owned input. These were assessed as nonblocking for this core commit. Physical adapter,
clock wrap, haptic failures, battery/memory measurements and watch export remain M0 blockers.

## Implementation decisions and corrections

Sessions are single-use: duplicate start preserves the first origin; a stopped or failed session
cannot be restarted. Construct another session to start again. Record drain transfers ownership
of detached records without affecting RR history or counters. Snapshot recursively copies arrays
and dictionaries. Cleanup attempts each registered resource once and continues if one stop throws;
actual cleanup/haptic error diagnostics remain adapter work.

The SDK compiler initially crashed on a conditional expression used directly as an indexed
increment target. Its diagnostic archive identified the failing RR function and phi node.
Assigning the counter key to a local variable before incrementing resolved the error under the
same compiler settings. Local evidence: `.local/evidence/core-compiler.zip`.

The first normal run exposed string reference comparisons in the implementation and test lookup,
plus SDK null-assertion errors. String comparisons now use `.equals`. Null expectations use
`Test.assert(actual == null)` because `Test.assertEqual` requires a non-null first argument.
The measured-zero RMSSD case uses the existing numeric tolerance helper rather than type-specific
object equality. Expectations remain unchanged. Diagnostic instrumentation was removed.

## Reproduce from a clean checkout

Install the locked formatter dependencies with `npm ci`. Obtain the SDK and vívoactive 5 device
package using Garmin's SDK manager, and provide a local signing key at the path below.
Start the Connect IQ simulator before running tests. No real watch sensors are used by this suite.

Generate the ignored test build descriptor from the repository root:

```sh
mkdir -p .local/probe-tests .local/evidence
cat > .local/probe-tests/tests.jungle <<'EOF'
project.manifest = ../../probe/tests/manifest.xml
base.sourcePath = ../../probe/source;../../probe/tests/cases;../../probe/tests/support
base.resourcePath = ../../probe/tests/resources
EOF
npm run format:check
sdk_path=$(cat '/Users/jasminetan/Library/Application Support/Garmin/ConnectIQ/current-sdk.cfg')
"$sdk_path/bin/monkeyc" -f .local/probe-tests/tests.jungle \
  -d vivoactive5 -y .local/keys/developer_key.der \
  -o .local/probe-tests/SensorProbe-tests.prg -t -l 0 -w
"$sdk_path/bin/monkeydo" .local/probe-tests/SensorProbe-tests.prg vivoactive5 -t
```

Type-check level 0 permits dynamic platform injection and intentional invalid-input fixtures;
syntax and undefined symbols remain checked. No real watch adapter or distributable application
build is claimed. The simulator exits with status 1 even when tests pass on this installation;
inspect the named results and summary. Green logs are retained locally as
`.local/evidence/sensorprobe-core-build.log` and `.local/evidence/sensorprobe-core-tests.log`.
