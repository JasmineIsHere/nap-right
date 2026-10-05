# SensorProbe watch build and first tests

SensorProbe is a diagnostic app, not the finished NapRight sleep detector. Its timer starts when
you start the test. The app does not promise that wrist RR is exposed, that recording survives
screen-off, or that requesting vibration means it physically occurred.

## Build and install

Run `npm ci --ignore-scripts`, `npm run format:check`, then `npm test`. The locked project formatter
covers Monkey C, XML and JavaScript. Node is required. Garmin SDK/device files and a private DER
key at `.local/keys/developer_key.der` are machine-local prerequisites. Never share the key.
`tools/build.js` generates ignored descriptors, verifies every named test exactly once and checks
both test and production builds for warnings. It knows this simulator may return 1 even on pass.

Signed output: `.local/SensorProbe.prg`. The production manifest/source paths exclude tests and
red helpers. Target: vívoactive 5, API 5.2, round 390px display, Sensor permission only.

Connect the watch using a data cable. Discover its current MTP folders/object IDs; do not reuse
IDs from old sessions. Install only `SensorProbe.prg` into `Garmin/Apps`, and create an empty
`SensorProbe.txt` in `Garmin/Apps/LOGS` to enable Garmin diagnostic output. Preserve/back up any
existing files with those names before replacement. Verify uploaded bytes by downloading them.
Never delete unrelated watch files. Disconnect USB before attempting a wrist test.

## Controls

- Select or tap starts/stops. The default duration is two minutes.
- Swipe or next/previous changes the idle duration: 2, 20, 45, 66 minutes.
- During recording, swipe or next/previous toggles readings and details.
- Back stops an active session; Back while idle exits.
- Menu while idle prints the last saved report again. Before retrieval, avoid printing repeatedly:
  Garmin rotates logs and retains only a small history on this target API.

When the deadline is reached, the app requests two short vibration pulses and stops. The screen
says requested, not confirmed. Any actual app inactivity/exit interrupts the recording. A dark
screen alone does not stop it. Display updates are suppressed outside high-power mode, so the
app does not keep the screen lit for diagnostic rendering.

## First physical test

1. Note watch firmware, battery percentage, wrist-HR setting and screen settings. Disable other
   paired HR sensors for a wrist-only experiment using your normal watch controls; sensor source
   remains unverified by this app. Record those conditions in your notes.
2. Run a two-minute test while wearing the watch. Sit still, move your wrist, then remove and
   replace the watch. Note whether displayed readings change or become unavailable.
3. Record whether vibration happened, and approximately how late it was. A simulator/API call
   cannot prove this. Review errors and storage status on the detail/result screen.
4. Reconnect USB. Retrieve both `SensorProbe.TXT` (case may differ) and `SensorProbe.BAK` if
   present, preserving copies under `.local/evidence/`. Do not assume printing persisted them.
5. Decode with `node tools/decode.js CURRENT.txt BACKUP.BAK`. It validates the latest report
   across rotation and reports incomplete/truncated exports as errors. A valid `incomplete`
   trailer is a saved recovery snapshot, not a completed run.
6. Only after the short test succeeds, perform 20-, 45- and 66-minute trials while visible and
   dim/off. Record interruption circumstances, gaps, alarm delivery and start/end battery. Repeat
   runs to account for coarse battery percentages. Target <=8% battery drain/hour.

This report contains a tiny raw preview and bounded summaries. It does not export every raw
sample. Storage writes/export overflow errors invalidate persistence acceptance. Abrupt loss may
lose up to the last minute; the next launch offers the saved report without resuming recording.
Full raw/FIT export and an explicit M0 go/conditional-go/no-go decision remain separate gates.

## Report schema NP1

ASCII, comma-delimited, no quoted strings. Application-generated metadata and error codes contain
no commas/newlines. Integer counters/times below use base36 unless stated decimal; `_` means null.

- `NP1,id,durationMinutes,sampleRate,wallSeconds,build,firmware,api`: numeric header fields decimal.
- `P,kind,elapsedMs,wallSeconds,quality,unit,value,nativeTimestampMs`: wall time/value decimal;
  XYZ uses three semicolon-separated decimals. At most three previews for each HR/XYZ/RR kind.
  Missing/rejected previews have null values; null native timestamps remain null.
- `M,elapsedSeconds,hrAccepted,xyzAccepted,rrAccepted,missing,rejected,rrGaps,maxCallbackGapMs,offSeconds,batteryTenths,freeMemory,minFreeMemory`:
  increments since the prior summary; battery/memory are observations at checkpoint time.
  Off seconds are estimated from timer intervals and the display mode observed at interval end.
  A delayed callback produces one observed summary, not fabricated rows for missing minutes.
- `E,error_code`: at most eight unique bounded codes. Errors remain diagnostic observations.
- `A,scheduledMs,actualMs,requested|vibe_error`: one alarm attempt.
- `F,reason,elapsedMs,packedStats,precedingRowCount`: count decimal, stats colon-separated base36
  in order HR accepted/missing/rejected, XYZ accepted/missing/rejected, RR accepted/missing/rejected,
  dropped core records, RR gaps. Reason: complete/cancelled/interrupted/incomplete/startup_error.

Journal ASCII is checked against 24 KiB before storage; exported reports must fit 4096 bytes.
A valid 66-minute/25Hz synthetic report must fit and decode. `NP_ERROR,export_overflow` is a failed
export, not valid evidence. The stored journal is retained for recovery if export alone overflows.
