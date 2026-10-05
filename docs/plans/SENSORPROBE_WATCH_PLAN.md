# SensorProbe watch plan and gate ledger

Approved by the user on 2026-10-05 after Plan-mode exploration and independent plan review.
Reviewer `watch_adapter_plan_review`: No findings; APPROVE revised plan. Prior logging-retention
and RR-gap provenance findings were resolved before approval.

Build a standalone vívoactive 5 watch app using the existing core: 2/20/45/66-minute presets,
25 Hz acceleration constrained to supported maximum, 1-second batches, HR events, optional RR,
rollover-safe elapsed clock, stale-generation guards, explicit callback gaps, bounded storage and
compact USB diagnostic report. No sleep detector, activity recording, backend or FIT export.

Screen: Start/Stop through button/touch, duration chosen before recording, primary readings and
details/counters/battery/heap, unavailable/stale labels. Screen-off does not stop recording;
actual app inactivity/exit does. Deadline requests two 500 ms vibration pulses separated by
500 ms then stops. Record attempts/errors, not claims of confirmed physical delivery.

Driver: injectable Garmin API facade, independent cleanup, retry acceleration alone once after
RR registration failure; generation-bound callback relay. Add core rrGap(at,wall), rrGaps and
callback_gap record without incrementing rrMissingCallbacks.

Journal: bounded ASCII string <=24 KiB, first three examples of HR/XYZ/RR, <=66 minute summaries,
metadata, bounded error codes and final counters. Save start/minute/stop. Report <=4096 ASCII
bytes; one automatic emission per session, explicit last-export action. Decoder validates rows,
nulls/units/counters and truncated/rotated files; raw history is explicitly partial. Oversize/storage
failure is an error. Recover incomplete saved journal without resuming sensors. Retrieve TXT+BAK.

Validation: reviewed tests before implementation; retain 45 regressions; worst-case 66-minute
25 Hz fixture must fit/export/decode; warning-free signed test/production builds; format/check;
simulator layout/controls with Computer Use action log; fresh final review and commit, no push.
Installation: discover current USB folder IDs; preserve existing files; verify transferred bytes.
Physical wrist tests, continuity, battery/memory, retained logs and actual haptic timing remain
human hardware gates and cannot establish M0 go from simulator results.

## Gate checklist

- [x] Plan-mode exploration, independent plan approval and user implementation authorization.
- [x] New tests run red and independently approved after three review fixes.
      60 SDK tests: expected failures, zero errors. Six decoder cases plus actual fixture test red.
      Callback wiring/startup/stale tests and nonempty journal/content/decoder assertions added.
      Reviewer: No findings, APPROVE test suite; unused local removed.
- [x] Implementation, complete suites, formatting and signed builds pass.
      `npm test`: 61 SDK tests, zero failures/errors; eight Node tests pass, including
      actual 66-minute export. Both signed builds warning-free.
- [x] Simulator layout and button Start/Stop/details/duration checks logged in task.
      66-minute label fits the round display. Touch input remains physical acceptance.
- [x] Fresh final review approves. Commit hash recorded in the task after commit.
- [ ] Device transfer verified, or specific missing prerequisite reported.
- [ ] Human physical acceptance and M0 decision.

## Final review corrections

Fresh read-only reviewer `watch_final_review` identified two P2 defects: minimum memory leaked
between sessions, and decoding accepted negative minute counters/normalized times. Both have
regression tests independently approved by `watch_tests_review` (No findings, APPROVE). Red
runs reproduced the second-session memory assertion and decoder missing expected exception.
Fixes initialize memory from session-start metrics and reject negative normalized times/counters
while preserving signed acceleration/native timestamps. Final re-review: No findings; APPROVE for commit. Reviewer independently reran
format checking and eight Node tests and inspected SDK/build evidence.

Verified tools: Connect IQ 9.2.0, vívoactive 5/API 5.2 device files, Java, Node, locked Prettier
and Monkey C/XML plugins, local signing key, simulator and libmtp. Private keys and generated
artifacts remain ignored. Production excludes test sources. Formatting commands:
`npm run format` and `npm run format:check` pass. Complete validation command: `npm test`.
