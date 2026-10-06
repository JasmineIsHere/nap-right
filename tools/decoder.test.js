import test from "node:test";
import assert from "node:assert/strict";
import { decode } from "./decode.js";
const report =
    "NP1,test,2,25,1700000000,test,17.05,5.2.0\nP,hr,0,1700000000,valid,bpm,65,_\nM,1o,1o,15o,1o,0,0,0,rs,0,m8,apsw,apsw\nA,2klc,2lr0,vibe_error\nF,complete,2lr0,1o:0:0:15o:0:0:1o:0:0:0:0,4\n";
test("decodes units, counters and timing without claiming full raw history", () => {
    const d = decode(report);
    assert.equal(d.rawPartial, true);
    assert.equal(d.preview[0].value, 65);
    assert.equal(d.preview[0].unit, "bpm");
    assert.equal(d.minutes[0][0], 60);
    assert.equal(d.alarm.actual, 121500);
    assert.equal(d.stats.accelSamples, 1500);
});
test("rejects truncated and malformed exports", () => {
    assert.equal(decode(report).rawPartial, true);
    assert.throws(() => decode(report.slice(0, report.lastIndexOf("F,"))));
    assert.throws(() => decode(report.replace("15o", "!")));
    assert.throws(() => decode(report.replace(",4\n", ",99\n")));
});
test("reconstructs report across backup rotation", () => {
    let cut = report.indexOf("M,");
    let d = decode(report.slice(cut), report.slice(0, cut));
    assert.equal(d.preview.length, 1);
});
test("preserves unavailable values", () => {
    const d = decode(report.replace("valid,bpm,65,_", "missing,bpm,_,_"));
    assert.equal(d.preview[0].value, null);
    assert.equal(d.preview[0].quality, "missing");
});
test("rejects malformed previews, counters, final rows and trailing data", () => {
    assert.equal(decode(report).rawPartial, true);
    for (const bad of [
        report.replace("valid,bpm,65,_", "valid,watts,65,_"),
        report.replace("valid,bpm,65,_", "valid,bpm,oops,_"),
        report.replace("valid,bpm,65,_", "valid,bpm,65"),
        report.replace("1o:0:0:15o:0:0:1o:0:0:0:0", "1o:!:0:15o:0:0:1o:0:0:0:0"),
        report + report.slice(report.indexOf("F,")),
        report + "P,hr,",
        report.replace("valid,bpm,65,_", "valid,bpm,_,_"),
    ]) {
        assert.throws(() => decode(bad));
    }
});
test("preserves XYZ, RR and missing native timestamps", () => {
    const expanded = report
        .replace(
            "M,1o",
            "P,accel,a,1700000000,valid,millig,-1;2;1000,ab\nP,rr,b,1700000000,valid,ms,800,_\nM,1o",
        )
        .replace(",4\n", ",6\n");
    const d = decode(expanded);
    assert.deepEqual(d.preview[1].value, [-1, 2, 1000]);
    assert.equal(d.preview[1].sampleTimestampMs, 371);
    assert.equal(d.preview[2].value, 800);
    assert.equal(d.preview[2].sampleTimestampMs, null);
});

test("rejects negative normalized times and minute fields but preserves signed sensor data", () => {
    const bad = [
        report.replace("F,complete,2lr0", "F,complete,-1"),
        report.replace("P,hr,0,", "P,hr,-1,"),
        report.replace("A,2klc,2lr0", "A,-1,2lr0"),
        report.replace("A,2klc,2lr0", "A,2klc,-1"),
    ];
    const minute = report.split("\n").find((line) => line.startsWith("M,"));
    for (let i = 1; i < 13; i++) {
        const fields = minute.split(",");
        fields[i] = "-1";
        bad.push(report.replace(minute, fields.join(",")));
    }
    for (const text of bad) assert.throws(() => decode(text));
    const signed = report.replace(
        "P,hr,0,1700000000,valid,bpm,65,_",
        "P,accel,0,1700000000,valid,millig,-1;2;-3,-1",
    );
    assert.deepEqual(decode(signed).preview[0].value, [-1, 2, -3]);
    assert.equal(decode(signed).preview[0].sampleTimestampMs, -1);
});

function withPreview(kind, quality, value, nativeTimestamp = "_") {
    const unit = { hr: "bpm", rr: "ms", accel: "millig" }[kind];
    return report.replace(
        "P,hr,0,1700000000,valid,bpm,65,_",
        `P,${kind},0,1700000000,${quality},${unit},${value},${nativeTimestamp}`,
    );
}
for (const kind of ["hr", "rr"]) {
    test(`rejects nonpositive ${kind} previews marked valid`, () => {
        for (const value of ["0", "-0", "-1", "-0.5"]) {
            assert.throws(
                () => decode(withPreview(kind, "valid", value)),
                /Nonpositive valid HR or RR/,
                `${kind}=${value} must not be accepted as valid`,
            );
        }
    });
}
test("preserves positive HR/RR, absent values and signed acceleration", () => {
    for (const kind of ["hr", "rr"]) {
        for (const value of ["1", "0.5", kind === "hr" ? "65" : "800"]) {
            const preview = decode(withPreview(kind, "valid", value)).preview[0];
            assert.equal(preview.kind, kind);
            assert.equal(preview.value, Number(value));
            assert.equal(preview.quality, "valid");
        }
        for (const quality of ["missing", "rejected"]) {
            const preview = decode(withPreview(kind, quality, "_")).preview[0];
            assert.equal(preview.value, null);
            assert.equal(preview.quality, quality);
        }
    }
    const xyz = decode(withPreview("accel", "valid", "0;-1;2", "-1")).preview[0];
    assert.deepEqual(xyz.value, [0, -1, 2]);
    assert.equal(xyz.sampleTimestampMs, -1);
});
