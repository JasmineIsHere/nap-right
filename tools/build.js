import { readFileSync, writeFileSync, mkdirSync, readdirSync } from "node:fs";
import { join } from "node:path";
import { homedir } from "node:os";
import { spawnSync } from "node:child_process";
const sdk =
    process.env.GARMIN_SDK ||
    readFileSync(
        join(homedir(), "Library/Application Support/Garmin/ConnectIQ/current-sdk.cfg"),
        "utf8",
    ).trim();
mkdirSync(".local/probe-tests", { recursive: true });
mkdirSync(".local/evidence", { recursive: true });
function build(name, manifest, sources, resources, test) {
    const jungle = `project.manifest = ../../${manifest}\nbase.sourcePath = ${sources.map((p) => "../../" + p).join(";")}\nbase.resourcePath = ../../${resources}\n`;
    const path = `.local/probe-tests/${name}.jungle`;
    writeFileSync(path, jungle);
    const output = test ? ".local/probe-tests/SensorProbe-tests.prg" : ".local/SensorProbe.prg";
    const args = [
        "-f",
        path,
        "-d",
        "vivoactive5",
        "-y",
        ".local/keys/developer_key.der",
        "-o",
        output,
        "-l",
        "0",
        "-w",
    ];
    if (test) args.push("-t");
    const r = spawnSync(join(sdk, "bin/monkeyc"), args, {
        encoding: "utf8",
        maxBuffer: 16 * 1024 * 1024,
    });
    const log = (r.stdout || "") + (r.stderr || "");
    writeFileSync(`.local/evidence/watch-${test ? "" : "production-"}build.log`, log);
    if (
        r.error ||
        r.status !== 0 ||
        !log.includes("BUILD SUCCESSFUL") ||
        /WARNING:|ERROR:/.test(log)
    )
        throw Error("Build failed or produced warnings: " + log);
    console.log(name + ": signed build successful, no warnings");
    return output;
}
try {
    const file = build(
        "tests",
        "probe/tests/manifest.xml",
        ["probe/source", "probe/tests/cases", "probe/tests/support"],
        "probe/tests/resources",
        true,
    );
    const r = spawnSync(join(sdk, "bin/monkeydo"), [file, "vivoactive5", "-t"], {
        encoding: "utf8",
        maxBuffer: 16 * 1024 * 1024,
    });
    const log = (r.stdout || "") + (r.stderr || "");
    writeFileSync(".local/evidence/watch-tests.log", log);
    const expected = readdirSync("probe/tests/cases")
        .filter((p) => p.endsWith(".mc"))
        .flatMap((p) =>
            [
                ...readFileSync(join("probe/tests/cases", p), "utf8").matchAll(
                    /\(:test\)\s*function\s+(\w+)/g,
                ),
            ].map((m) => m[1]),
        )
        .sort();
    const actual = [...log.matchAll(/^(\w+)[ \t]+PASS[ \t]*\r?$/gm)].map((m) => m[1]).sort();
    if (
        r.error ||
        ![0, 1].includes(r.status) ||
        JSON.stringify(actual) !== JSON.stringify(expected) ||
        !log.includes(`PASSED (passed=${expected.length}, failed=0, errors=0)`)
    )
        throw Error(
            `Simulator suite failed (status=${r.status}, signal=${r.signal}, error=${r.error}, names=${actual.length}/${expected.length}); inspect .local/evidence/watch-tests.log`,
        );
    console.log(`${expected.length} simulator tests passed exactly once`);
    const js = spawnSync(
        process.execPath,
        ["--test", "tools/decoder.test.js", "tools/fixture.test.js"],
        {
            stdio: "inherit",
            env: { ...process.env, WATCH_SIM_LOG: ".local/evidence/watch-tests.log" },
        },
    );
    if (js.status !== 0) throw Error("Decoder tests failed");
    build(
        "production",
        "probe/manifest.xml",
        ["probe/source", "probe/app"],
        "probe/resources",
        false,
    );
} catch (e) {
    console.error(e.message);
    process.exitCode = 1;
}
