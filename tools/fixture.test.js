import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { decode } from "./decode.js";
test("actual 66-minute simulator export reconstructs measured counts and previews", () => {
    const log = readFileSync(
        process.env.WATCH_SIM_LOG || ".local/evidence/watch-red-tests.log",
        "utf8",
    );
    const m = log.match(/WATCH_FIXTURE_BEGIN\r?\n([\s\S]*?)WATCH_FIXTURE_END/);
    assert.ok(m, "Missing generated watch report; implementation must produce the fixture");
    const d = decode(m[1].trim() + "\n");
    assert.equal(d.preview.length, 9);
    assert.equal(d.minutes.length, 66);
    assert.equal(d.stats.hrSamples, 3960);
    assert.equal(d.stats.accelSamples, 99000);
    assert.equal(d.stats.rrSamples, 15840);
    assert.equal(d.preview.find((p) => p.kind === "hr").value, 200);
    assert.deepEqual(d.preview.find((p) => p.kind === "accel").value, [-32768, 32767, 1000]);
    assert.equal(d.preview.find((p) => p.kind === "rr").value, 300);
    assert.equal(d.alarm.scheduled, 3960000);
    assert.equal(d.alarm.actual, 3960000);
    assert.equal(d.reason, "complete");
    assert.ok(m[1].length <= 4096);
});
