# SensorProbe physical-test checkpoint — 2026-10-06

Implementation checkpoint: `eaf25c1` on `codex/sensorprobe-core`. The working tree was clean
before this record. Core/watch/startup diagnostics/onboard-HR fixes are already committed:
`4459947`, `d5e718c`, `47e060a`, `eaf25c1`. No push was performed.

## Evidence and acceptance

The user confirmed recording starts and heart rate appears on the vívoactive 5. Retrieved
watch-generated `SensorProbe.txt` from Garmin/Apps/LOGS via MTP; no SensorProbe backup log was
present in the current listing. The report was decoded and validated locally. Raw logs, signing
keys and compiled apps remain in ignored local folders.

The completed two-minute run, session `1791280438-2`, reports:

- Firmware 17.5, Connect IQ API 5.2.0, acceleration configured at 25 Hz.
- Completion at 120205 ms, with 120 accepted HR readings, 2975 XYZ samples and 81 RR intervals.
- Zero missing/rejected counters, dropped core records or recorded callback gaps.
- Alarm scheduled at 120000 ms; vibration requested at 120015 ms. Physical delivery is unverified.
- Two minute summaries. Battery observation was 100% at both checkpoints. No display-off time
  was recorded; lowest observed free memory was 753416 bytes.
- No recorded errors. The duplicate report has the same session ID and is not a second trial.

A separate later session `1791280577-1` ended interrupted after 489 ms with one HR reading.
It does not invalidate the completed run. This checkpoint establishes short-session sensor
capture and persistence/retrieval; it does not establish every sample's continuity, RR source,
physical vibration, screen-off survival, battery drain or sleep-onset detection.

## Validation and gates

- [x] Approved implementation plan and independent test/final reviews recorded in the task.
- [x] Onboard sensor selection repair reproduced by real-adapter tests before the fix.
- [x] `npm run format` and `npm run format:check`: passed.
- [x] `npm test`: 66 named SDK tests, zero failures/errors; eight Node tests passed.
- [x] Signed production and test builds: warning-free.
- [x] Device transfer downloaded back and verified byte for byte.
- [x] Short physical session and watch-generated report retrieved/decoded.
- [ ] Longer visible/dim/off trials, touch acceptance, physical vibration and battery tests.
- [ ] Full raw/FIT investigation and M0 go/conditional-go/no-go decision.

## Technical-debt review

Independent read-only reviewer `checkpoint_debt_review` inspected `2c1c196..eaf25c1`, tests,
call sites and physical evidence. The reviewer approved this documentation-only checkpoint,
subject to recording the following findings. The implementation is not approved as defect-free.
App behavior is frozen for this checkpoint; all three findings are deferred, not resolved.

- **P2 — Expire stale RR history independently of movement callbacks.** At
  `probe/source/ProbeController.mc:276`, XYZ callbacks containing empty RR arrays keep the
  generic callback timer fresh. The old RMSSD remains available and can bridge an RR hiatus.
  Follow-up: track RR measurement freshness separately, expire the calculation segment and
  test empty RR delivery while XYZ continues. This does not establish RR continuity from the
  current completed run's zero callback-gap counter.
- **P2 — Reject nonpositive valid HR/RR previews.** At `tools/decode.js:98`, numeric and null
  validation permits zero/negative HR or RR marked valid, although the producer requires
  positive readings. Follow-up: reject these malformed previews and test both HR and RR;
  preserve signed XYZ readings and native timestamps.
- **P3 — Update obsolete test reproduction instructions.** At
  `docs/validation/SENSORPROBE_IMPLEMENTATION.md:65`, the descriptor includes current tests
  but omits `probe/app`, which defines their GarminApi dependency. Follow-up: direct readers
  to maintained `npm test`, or label the old commands historical with their matching revision.

Review verification: formatting and whitespace checks passed; the reviewer independently ran
all eight Node tests successfully and inspected the 66-test SDK and successful signed-build
logs. The simulator/builds and hardware trials were not rerun for this documentation-only
checkpoint. Review gaps include both P2 regression cases and the outstanding hardware gates.
This checkpoint commit records evidence and debt; it adds no runtime changes.
