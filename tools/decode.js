import { readFileSync } from "node:fs";
import { pathToFileURL } from "node:url";
const names = [
    "hrSamples",
    "hrMissing",
    "hrRejected",
    "accelSamples",
    "accelMissing",
    "accelRejected",
    "rrSamples",
    "rrMissingCallbacks",
    "rrRejected",
    "droppedRecords",
    "rrGaps",
];
function integer(s) {
    if (!/^-?[0-9a-z]+$/.test(s)) throw Error("Invalid base36 integer");
    const n = parseInt(s, 36);
    if (!Number.isSafeInteger(n)) throw Error("Integer out of range");
    return n;
}
function nonnegative(s) {
    const n = integer(s);
    if (n < 0) throw Error("Negative counter or elapsed time");
    return n;
}
function number(s) {
    if (s === "_") return null;
    if (!/^-?\d+(?:\.\d+)?$/.test(s)) throw Error("Invalid numeric reading");
    const n = Number(s);
    if (!Number.isFinite(n)) throw Error("Nonfinite reading");
    return n;
}
export function decode(current, backup = "") {
    const combined = backup + current;
    if (combined.length > 10000 || /[^\x09\x0a\x0d\x20-\x7e]/.test(combined))
        throw Error("Invalid report size or encoding");
    const start = combined.lastIndexOf("NP1,");
    if (start < 0) throw Error("Missing header");
    const text = combined.slice(start).replace(/\r/g, "");
    if (!text.endsWith("\n")) throw Error("Truncated line");
    const rows = text
        .trimEnd()
        .split("\n")
        .map((s) => s.split(","));
    const h = rows.shift();
    if (
        h.length !== 8 ||
        h[0] !== "NP1" ||
        ![2, 20, 45, 66].includes(Number(h[2])) ||
        !/^\d+$/.test(h[4])
    )
        throw Error("Invalid header");
    const result = {
        sessionId: h[1],
        durationMinutes: Number(h[2]),
        sampleRate: Number(h[3]),
        wallSeconds: Number(h[4]),
        build: h[5],
        firmware: h[6],
        api: h[7],
        rawPartial: true,
        preview: [],
        minutes: [],
        errors: [],
        alarm: null,
        stats: {},
    };
    if (!Number.isInteger(result.sampleRate) || result.sampleRate < 1 || result.sampleRate > 25)
        throw Error("Invalid sample rate");
    const end = rows.pop();
    if (
        end?.[0] !== "F" ||
        end.length !== 5 ||
        Number(end[4]) !== rows.length + 1 ||
        !["complete", "cancelled", "interrupted", "incomplete", "startup_error"].includes(end[1])
    )
        throw Error("Missing or invalid trailer");
    result.reason = end[1];
    result.elapsedMs = nonnegative(end[2]);
    const counts = end[3].split(":");
    if (counts.length !== 11) throw Error("Invalid counters");
    counts.forEach((v, i) => {
        result.stats[names[i]] = integer(v);
        if (result.stats[names[i]] < 0) throw Error("Negative counter");
    });
    for (const r of rows) {
        if (r[0] === "P") {
            if (
                r.length !== 8 ||
                !["hr", "accel", "rr"].includes(r[1]) ||
                !["valid", "missing", "rejected"].includes(r[4]) ||
                r[5] !== { hr: "bpm", accel: "millig", rr: "ms" }[r[1]]
            )
                throw Error("Invalid preview");
            const v =
                r[6] === "_" ? null : r[1] === "accel" ? r[6].split(";").map(number) : number(r[6]);
            if (
                (r[4] === "valid" && v === null) ||
                (r[4] !== "valid" && v !== null) ||
                (r[1] === "accel" && v !== null && (v.length !== 3 || v.some((x) => x === null)))
            )
                throw Error("Invalid preview value");
            if (!/^\d+$/.test(r[3])) throw Error("Invalid capture time");
            result.preview.push({
                kind: r[1],
                elapsedMs: nonnegative(r[2]),
                wallSeconds: Number(r[3]),
                quality: r[4],
                unit: r[5],
                value: v,
                sampleTimestampMs: r[7] === "_" ? null : integer(r[7]),
            });
        } else if (r[0] === "M") {
            if (r.length !== 13) throw Error("Invalid minute");
            result.minutes.push(r.slice(1).map(nonnegative));
        } else if (r[0] === "A") {
            if (r.length !== 4 || result.alarm || !["requested", "vibe_error"].includes(r[3]))
                throw Error("Invalid alarm");
            result.alarm = {
                scheduled: nonnegative(r[1]),
                actual: nonnegative(r[2]),
                status: r[3],
            };
        } else if (r[0] === "E") {
            if (r.length !== 2 || !/^[a-z_]{1,32}$/.test(r[1])) throw Error("Invalid error");
            result.errors.push(r[1]);
        } else throw Error("Unknown row");
    }
    if (result.preview.length > 9 || result.minutes.length > 66) throw Error("Oversize report");
    return result;
}
if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
    try {
        console.log(
            JSON.stringify(
                decode(
                    readFileSync(process.argv[2], "utf8"),
                    process.argv[3] ? readFileSync(process.argv[3], "utf8") : "",
                ),
                null,
                2,
            ),
        );
    } catch (e) {
        console.error(e.message);
        process.exitCode = 1;
    }
}
