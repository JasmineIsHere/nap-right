import Toybox.Lang;
class ProbeController {
    var api;
    var clock;
    var session = null;
    var journal = null;
    var generation = 0;
    var running = false;
    var rate = 25;
    var rrEnabled = true;
    var storageOk = true;
    var duration = 2;
    var elapsed = 0;
    var lastData = 0;
    var lastHr = 0;
    var gapLatched = false;
    var latestHr = null;
    var latestAccel = null;
    var latestRr = null;
    var nextMinute = 60000;
    var previousStats = null;
    var maxGap = 0;
    var offMs = 0;
    var lastTick = 0;
    var minFree = 786432;
    var reportText = null;
    var recovered = null;
    var errors = [];
    function initialize(driver) {
        api = driver;
        try {
            recovered = api.load();
        } catch (e) {
            storageOk = false;
        }
    }
    function error(code) {
        if (journal != null) {
            journal.error(code);
            errors = journal.errors;
        } else {
            errors.add(code);
        }
    }
    function start(minutes) {
        if (running) {
            return false;
        }
        if (!(minutes == 2 || minutes == 20 || minutes == 45 || minutes == 66)) {
            return false;
        }
        generation += 1;
        duration = minutes;
        clock = new ProbeClock(api);
        elapsed = 0;
        lastData = 0;
        lastHr = 0;
        nextMinute = 60000;
        maxGap = 0;
        offMs = 0;
        lastTick = 0;
        minFree = api.metrics()["free"];
        gapLatched = false;
        rrEnabled = true;
        storageOk = true;
        latestHr = null;
        latestAccel = null;
        latestRr = null;
        reportText = null;
        errors = [];
        journal = new ProbeJournal(
            api.wallTime().toString() + "-" + generation,
            api.wallTime(),
            api.metadata(),
            25,
            minutes
        );
        var platform = new ProbePlatform(api, new ProbeRelay(self, generation), self);
        session = (new ProbeFactory()).create(
            { "recordCapacity" => 512, "rrCapacity" => 30, "alarmDelayMs" => minutes * 60000 },
            platform
        );
        running = session.start(0, api.wallTime());
        // Metadata must reflect the rate determined by registration, including failures.
        var meta = api.metadata();
        journal.header =
            "NP1," +
            api.wallTime() +
            "-" +
            generation +
            "," +
            minutes +
            "," +
            rate +
            "," +
            api.wallTime() +
            "," +
            meta[0] +
            "," +
            meta[1] +
            "," +
            meta[2] +
            "\n";
        if (!running) {
            error("startup_error");
        }
        consume();
        previousStats = session.snapshot()["stats"];
        persist(running ? "incomplete" : "startup_error");
        return running;
    }
    function active(g) {
        return running && g == generation;
    }
    function consume() {
        var records = session.drain();
        journal.observe(records);
        for (var i = 0; i < records.size(); i += 1) {
            var r = records[i];
            if (!r.hasKey("quality") || !r["quality"].equals("valid")) {
                continue;
            }
            if (r["kind"].equals("hr")) {
                latestHr = r["value"];
            }
            if (r["kind"].equals("accel")) {
                latestAccel = r["value"];
            }
            if (r["kind"].equals("rr")) {
                latestRr = r["value"];
            }
        }
    }
    function onHr(g, value) {
        if (!active(g)) {
            return;
        }
        elapsed = clock.elapsed();
        lastHr = elapsed;
        latestHr = null;
        session.heartRate(elapsed, api.wallTime(), value);
        consume();
    }
    function onData(g, payload, rr) {
        if (!active(g)) {
            return;
        }
        elapsed = clock.elapsed();
        var gap = elapsed - lastData;
        if (gap > maxGap) {
            maxGap = gap;
        }
        if (gap > 3000 && !gapLatched) {
            session.rrGap(elapsed, api.wallTime());
        }
        lastData = elapsed;
        gapLatched = false;
        latestAccel = null;
        latestRr = null;
        session.accelerometer(elapsed, api.wallTime(), payload);
        session.rr(elapsed, api.wallTime(), rr);
        consume();
    }
    function onTick(g) {
        if (!active(g)) {
            return;
        }
        elapsed = clock.elapsed();
        var metrics = api.metrics();
        if (metrics["mode"] == 2) {
            offMs += elapsed - lastTick;
        }
        lastTick = elapsed;
        if (metrics["free"] < minFree) {
            minFree = metrics["free"];
        }
        var gap = elapsed - lastData;
        if (gap > maxGap) {
            maxGap = gap;
        }
        if (gap > 3000 && !gapLatched) {
            gapLatched = true;
            session.rrGap(elapsed, api.wallTime());
            consume();
        }
        if (elapsed >= nextMinute && journal.minutes.size() < 66) {
            var s = session.snapshot()["stats"];
            var p = previousStats;
            journal.minutes.add([
                elapsed / 1000,
                s["hrSamples"] - p["hrSamples"],
                s["accelSamples"] - p["accelSamples"],
                s["rrSamples"] - p["rrSamples"],
                s["hrMissing"] +
                    s["accelMissing"] +
                    s["rrMissingCallbacks"] -
                    p["hrMissing"] -
                    p["accelMissing"] -
                    p["rrMissingCallbacks"],
                s["hrRejected"] +
                    s["accelRejected"] +
                    s["rrRejected"] -
                    p["hrRejected"] -
                    p["accelRejected"] -
                    p["rrRejected"],
                s["rrGaps"] - p["rrGaps"],
                maxGap,
                offMs / 1000,
                metrics["battery"],
                metrics["free"],
                minFree,
            ]);
            previousStats = s;
            nextMinute = elapsed + 60000;
            maxGap = 0;
            offMs = 0;
            persist("incomplete");
        }
        session.tick(elapsed, api.wallTime());
        consume();
        if (journal.alarm != null) {
            stop("complete");
        }
    }
    function persist(reason) {
        var text = journal.report(reason, elapsed, session.snapshot()["stats"]);
        if (text.length() > 24576) {
            storageOk = false;
            error("journal_overflow");
            return;
        }
        try {
            api.save(text);
            recovered = text;
        } catch (e) {
            storageOk = false;
            error("storage_error");
        }
    }
    function stop(reason) {
        if (!running) {
            return;
        }
        elapsed = clock.elapsed();
        running = false;
        session.stop(elapsed, api.wallTime(), reason);
        consume();
        persist(reason);
        reportText = journal.report(reason, elapsed, session.snapshot()["stats"]);
        if (reportText.length() > 4096) {
            error("export_overflow");
            reportText = "NP_ERROR,export_overflow\n";
        }
        api.emit(reportText);
    }
    function exportLast() {
        var text = reportText != null ? reportText : recovered;
        if (text == null || text.length() > 4096) {
            return false;
        }
        api.emit(text);
        return true;
    }
    function state() {
        var s = session == null ? null : session.snapshot();
        var metrics = api.metrics();
        return {
            "running" => running,
            "generation" => generation,
            "elapsed" => elapsed,
            "duration" => duration,
            "rate" => rate,
            "rrEnabled" => rrEnabled,
            "storageOk" => storageOk,
            "stats" => s == null ? {} : s["stats"],
            "rmssd" => s == null ? null : s["rmssdMs"],
            "hr" => elapsed - lastHr > 3000 ? null : latestHr,
            "accel" => elapsed - lastData > 3000 ? null : latestAccel,
            "rr" => elapsed - lastData > 3000 ? null : latestRr,
            "errors" => errors,
            "alarm" => journal == null ? null : journal.alarm,
            "report" => reportText,
            "metrics" => metrics,
            "recovered" => recovered != null,
        };
    }
}
