# M0 preparation — vívoactive 5

Verified on 5 October 2026 (Asia/Singapore).

## Purpose and scope

Prepare the development and transfer tools for SensorProbe, the first milestone of the supplied
NapRight implementation plan. The PoC will estimate sleep onset on a Garmin watch and then start
a fixed 20-minute timer. This preparation does not implement SensorProbe or establish sleep
detection, continuous wrist RR access, screen-off execution, alarm reliability, or battery life.

Source roadmap: `/Users/jasminetan/Documents/Codex/2026-09-28/referenced-chatgpt-conversation-this-is-an/outputs/NAPRIGHT_IMPLEMENTATION_PLAN.md`.
The supplied document is a product and implementation proposal; repository procedure comes from
`AGENTS.md`. The user confirmed vívoactive 5 as the initial target and allowed Garmin Connect sync
for diagnostics. Processing remains on the watch, with no custom backend.

## Verified tools and device

| Item                   | Evidence                                                                   | Outcome                                                                        |
| ---------------------- | -------------------------------------------------------------------------- | ------------------------------------------------------------------------------ |
| Connect IQ compiler    | `monkeyc --version`                                                        | Compiler 9.2.0 runs successfully                                               |
| SDK discovery          | Garmin `current-sdk.cfg`                                                   | `connectiq-sdk-mac-9.2.0-2026-06-09-92a1605b2`                                 |
| Java                   | `/usr/libexec/java_home -V`                                                | Temurin OpenJDK 25.0.3, arm64; successful SDK build                            |
| Target package         | Installed `Devices/vivoactive5/compiler.json`                              | API group 5.2; device ID `vivoactive5`                                         |
| Display and app memory | Same target metadata                                                       | Round AMOLED, **390×390**, watch-app memory limit 786432 bytes                 |
| Simulator              | SDK `connectiq` launcher and Computer Use window inspection                | CIQ Simulator window present; simulator test execution verified                |
| Build signing          | `openssl pkey -inform DER -in .local/keys/developer_key.der -check -noout` | Key valid; signed smoke build succeeds                                         |
| Formatting             | `npm run format:check`                                                     | Prettier with Monkey C and XML plugins configured                              |
| USB connection         | `mtp-detect`                                                               | Garmin vívoactive 5, reported device version `1705`                            |
| File transfer          | `mtp-folders`, synthetic upload, download and `cmp`                        | `Garmin/Apps/LOGS` accessible; synthetic file round trip matches byte for byte |
| MTP tools              | Homebrew installation                                                      | libmtp 1.1.23 and libusb 1.0.30 installed                                      |

The SDK's API group is target-package metadata, not a measurement of the watch's running API
version. Record actual firmware/API information during SensorProbe hardware testing.

The original roadmap's 360×360 display assumption is corrected to the installed target package's
390×390 size. Use device dimensions and verify layout in the target simulator.

## Validation evidence and limitations

All local keys, copied SDK samples, downloaded tools, compiled outputs and raw diagnostic logs
are under ignored `.local/`. Key files also have restrictive filesystem permissions. Do not commit
or share private keys. Keep a private backup before relying on this signing identity for releases.

The installed SDK's Sensor sample was copied to `.local/smoke/Sensor`; its copied manifest was
restricted to `vivoactive5` and English. Original SDK source files were not edited. The copied
Monkey C and manifest XML were formatted before the final smoke build.

Build command (set `sdk_path` to the path in Garmin's `current-sdk.cfg`):

```sh
"$sdk_path/bin/monkeyc" -f .local/smoke/Sensor/monkey.jungle \
  -d vivoactive5 -y .local/keys/developer_key.der \
  -o .local/smoke/Sensor-tests.prg -t -w
```

Result: `BUILD SUCCESSFUL`. The SDK sample's 16×16 launcher icon produces a warning because the
target requires 56×56; this sample is a disposable environment check, not the probe's UI.

The disposable harness checks test discovery and result reporting:

```sh
"$sdk_path/bin/monkeydo" .local/smoke/Sensor-tests.prg vivoactive5 -t toolchainPass
"$sdk_path/bin/monkeydo" .local/smoke/Sensor-tests.prg vivoactive5 -t toolchainIntentionalFailure
```

- `toolchainPass`: one test, `PASSED (passed=1, failed=0, errors=0)`.
- `toolchainIntentionalFailure`: expected assertion failure, `FAILED (passed=0, failed=0, errors=1)`.
- Both launcher invocations returned exit code **1**. A future test runner must require the
  expected named tests and a complete successful summary, reject failures/errors or missing
  results, and reject unexpected process failures. Exit status alone cannot distinguish these runs.
- These checks validate the environment only. They are not SensorProbe's feature test suite.

Raw build/test outputs: `.local/evidence/smoke-build.log`, `test-runner-pass.log` and
`test-runner-failure.log`.

The watch uses MTP and does not appear as a mounted Finder volume. libmtp reports the USB
VID/PID as unknown and emits metadata/PTP warnings during folder enumeration, but identifies
the watch and enumerates `Garmin/Apps`, `LOGS`, `DATA` and `Activity`. Do not assume a zero tool
exit status means a transfer succeeded; verify retrieved bytes.

Only a synthetic text file containing no personal or sensor data was uploaded and retrieved.
It remains at `Garmin/Apps/LOGS/NapRightM0Transfer-20261005.txt`; the upload returned object ID 16781836. Folder/object IDs are session/device observations, not portable constants.
No app was installed on the physical watch and no existing watch files were changed or deleted.

```sh
mtp-sendfile .local/evidence/NapRightM0Transfer-20261005.txt 16777282
mtp-getfile 16781836 .local/evidence/NapRightM0Transfer-20261005-returned.txt
cmp .local/evidence/NapRightM0Transfer-20261005.txt \
  .local/evidence/NapRightM0Transfer-20261005-returned.txt
```

Upload and download returned 0; byte comparison returned 0. This proves the observed file-transfer
path, not a watch-generated diagnostic export or FIT round trip. Those remain M0 hardware tasks.

OpenMTP 3.3.0 was downloaded from its official release but **not launched**: the archive passed
ZIP integrity checks, while macOS code-signature verification failed after both extraction methods.
No signature or security checks were bypassed. libmtp provides the verified alternative.

## Formatting and reproducibility

Dependencies are pinned in `package.json` and `package-lock.json`. Only development formatters
are installed; there is no runtime backend or phone application.

```sh
npm ci --ignore-scripts
npm run format
npm run format:check
```

The scripts cover tooling JSON, new documents and future Monkey C/XML files under `probe/`.
They deliberately exclude existing `AGENTS.md`, SDK files, ignored local artifacts and unrelated
user files. For explicit disposable-harness checks, use:

```sh
./node_modules/.bin/prettier --ignore-path /dev/null --write \
  '.local/smoke/Sensor/source/*.mc' .local/smoke/Sensor/manifest.xml
./node_modules/.bin/prettier --ignore-path /dev/null --check \
  '.local/smoke/Sensor/source/*.mc' .local/smoke/Sensor/manifest.xml
```

Temporary smoke sources are local evidence, not a supported project or committed test suite.
A fresh checkout restores the formatter through `npm ci`; SDK, signing key, MTP tools and smoke
artifacts must be prepared on that machine separately.

## Gate checklist

- [x] Explore: empty repository and applicable `AGENTS.md` inspected in Plan mode.
- [x] Roadmap reviewed: reviewer `/root/plan_review` reported `No findings.` and explicitly
      approved the staged roadmap and M0 scope. Hardware feasibility was not claimed.
- [x] User scope confirmed: vívoactive 5 and Garmin diagnostic synchronization permitted.
- [x] Compiler, Java, simulator, target files, signing, formatter and USB transfer verified.
- [x] Environment self-checks distinguish passing tests from intentional assertion failures.
- [x] Preparation change receives fresh read-only final review; decision recorded below.
- [ ] Preparation changes committed after formatting checks and reviewer approval.
- [ ] Define and review SensorProbe's complete feature tests before probe implementation.
- [ ] Implement and review SensorProbe, with its reviewed feature tests passing.
- [ ] Install SensorProbe and collect physical visible/dim/off, interruption, sensor and alarm data.
- [ ] Measure long-duration battery/memory, prove watch-generated diagnostic extraction, and
      record M0 go / conditional go / no-go. Do not proceed to the full detector without that decision.

SensorProbe tests must cover timestamped HR/XYZ/RR capture with explicit units, absent/invalid
data without fabrication, sample/rejection/gap counters, bounded buffers and overflow reporting,
known RMSSD fixtures without bridging gaps, one-shot delayed alarm deadlines, idempotent cleanup,
and record reconstruction. Simulator checks cannot establish physical sensor availability or
battery and alarm guarantees.

## Computer Use action log

The user requested an action log whenever Computer Use is active.

1. Selected the installed Garmin simulator application to verify it was running.
2. The first selection waited for macOS Accessibility/Screen Recording authorization.
3. Retried the selection; read the `CIQ Simulator` window's accessibility state.
4. No simulator controls were clicked or settings changed through Computer Use.

Subsequent preparation used command-line tools. Log future UI actions in commentary when taken.

## Review and commit record

Fresh reviewer `/root/preparation_review` reported **No findings.** and explicitly approved
**committing preparation only**. The reviewer independently verified compiler execution, the
valid ignored signing key, build/test logs, synthetic transfer byte equality, and project/harness
formatting checks. Residual risks are the pending SensorProbe feature suite and physical validation.

This is the pre-commit evidence snapshot. The resulting commit hash is reported in the task after
the commit succeeds. The preparation scope adds formatter configuration, ignore rules and this
evidence record; it contains no production watch code.
