import Toybox.Test;
import Toybox.System;
(:test)
function watchRateAndRrFallback(logger) {
    var api = new WatchFakeApi();
    api.maxRate = 10;
    api.failRr = true;
    var c = newWatchTest(logger, api);
    if (c == null) {
        return false;
    }
    Test.assert(c.start(2));
    Test.assertEqual(api.registrations.size(), 2);
    Test.assertEqual(api.registrations[0][0], 10);
    Test.assertEqual(api.registrations[0][1], true);
    Test.assertEqual(api.registrations[1][1], false);
    Test.assertEqual(api.unregistrations, 1);
    Test.assertEqual(c.state()["rrEnabled"], false);
    c.stop("cancelled");
    return true;
}
(:test)
function watchPartialStartupCleanup(logger) {
    var api = new WatchFakeApi();
    api.failAllData = true;
    api.failCleanup = true;
    var c = newWatchTest(logger, api);
    if (c == null) {
        return false;
    }
    Test.assert(!c.start(2));
    Test.assertEqual(api.hrStops, 1);
    Test.assertEqual(c.state()["running"], false);
    Test.assert(c.state()["errors"].size() >= 2);
    return true;
}
(:test)
function watchTimerFailureCleanup(logger) {
    var api = new WatchFakeApi();
    api.failTimer = true;
    var c = newWatchTest(logger, api);
    if (c == null) {
        return false;
    }
    Test.assert(!c.start(2));
    Test.assertEqual(api.hrStops, 1);
    Test.assertEqual(api.unregistrations, 1);
    Test.assertEqual(api.timerStops, 1);
    return true;
}
(:test)
function watchMissingIntervalsAndGapProvenance(logger) {
    var api = new WatchFakeApi();
    var c = newWatchTest(logger, api);
    if (c == null) {
        return false;
    }
    c.start(2);
    var g = c.state()["generation"];
    c.onData(g, null, [800, 900]);
    api.now = 4000;
    c.onTick(g);
    c.onTick(g);
    Test.assert(c.state()["rmssd"] == null);
    Test.assertEqual(c.state()["stats"]["rrGaps"], 1);
    Test.assertEqual(c.state()["stats"]["rrMissingCallbacks"], 0);
    c.onData(g, null, [1000, 1200]);
    assertNearMs(c.state()["rmssd"], 200);
    c.onData(g, null, null);
    Test.assertEqual(c.state()["stats"]["rrMissingCallbacks"], 1);
    c.stop("cancelled");
    return true;
}
(:test)
function watchSignedClockRolloverAndWallJump(logger) {
    var api = new WatchFakeApi();
    api.now = 2147483640;
    var c = newWatchTest(logger, api);
    if (c == null) {
        return false;
    }
    c.start(2);
    api.now = -2147483640;
    api.wall = 1;
    c.onTick(c.state()["generation"]);
    Test.assertEqual(c.state()["elapsed"], 16);
    Test.assertEqual(api.vibes, 0);
    c.stop("cancelled");
    return true;
}
(:test)
function watchDelayedAlarmAndHapticFailure(logger) {
    var api = new WatchFakeApi();
    api.failVibe = true;
    var c = newWatchTest(logger, api);
    if (c == null) {
        return false;
    }
    c.start(2);
    var g = c.state()["generation"];
    api.now = 121500;
    c.onTick(g);
    c.onTick(g);
    Test.assertEqual(api.vibes, 1);
    Test.assertEqual(c.state()["running"], false);
    Test.assert(c.state()["errors"].size() > 0);
    Test.assertEqual(c.state()["alarm"][0], 120000);
    Test.assertEqual(c.state()["alarm"][1], 121500);
    Test.assertEqual(api.outputs.size(), 1);
    return true;
}
(:test)
function watchStaleCallbacksAndCancellation(logger) {
    var api = new WatchFakeApi();
    var c = newWatchTest(logger, api);
    if (c == null) {
        return false;
    }
    c.start(2);
    var old = c.state()["generation"];
    c.stop("cancelled");
    c.start(2);
    var current = c.state()["generation"];
    c.onHr(old, 60);
    c.onData(old, null, [800, 900]);
    api.now = 120001;
    c.onTick(old);
    Test.assertEqual(c.state()["stats"]["hrSamples"], 0);
    Test.assertEqual(api.vibes, 0);
    c.onHr(current, 70);
    Test.assertEqual(c.state()["stats"]["hrSamples"], 1);
    c.stop("cancelled");
    c.stop("cancelled");
    Test.assertEqual(api.hrStops, 2);
    return true;
}
(:test)
function watchScreenOffAndStorageFailure(logger) {
    var api = new WatchFakeApi();
    api.mode = 2;
    api.failStorage = true;
    var c = newWatchTest(logger, api);
    if (c == null) {
        return false;
    }
    c.start(2);
    api.now = 60000;
    c.onTick(c.state()["generation"]);
    Test.assertEqual(c.state()["running"], true);
    Test.assert(c.state()["storageOk"] == false);
    c.stop("interrupted");
    Test.assertEqual(api.vibes, 0);
    return true;
}
(:test)
function watchWorstCaseJournalAndReport(logger) {
    var api = new WatchFakeApi();
    var c = newWatchTest(logger, api);
    if (c == null) {
        return false;
    }
    c.start(66);
    var g = c.state()["generation"];
    for (var i = 0; i < 3960; i += 1) {
        api.now = i * 1000;
        var xs = [];
        var ys = [];
        var zs = [];
        var ts = [];
        for (var j = 0; j < 25; j += 1) {
            xs.add(-32768);
            ys.add(32767);
            zs.add(1000);
            ts.add(i * 1000 + j * 40);
        }
        c.onHr(g, 200);
        c.onData(g, { "x" => xs, "y" => ys, "z" => zs, "timestamp" => ts }, [300, 400, 500, 600]);
        c.onTick(g);
    }
    api.now = 3960000;
    c.onTick(g);
    Test.assertEqual(c.state()["stats"]["accelSamples"], 99000);
    Test.assertEqual(api.outputs.size(), 1);
    Test.assertEqual(api.saves.size(), 68);
    Test.assert(api.outputs[0].length() <= 4096);
    Test.assertEqual(api.outputs[0].find("NP1,"), 0);
    Test.assert(api.outputs[0].find("F,complete,") != null);
    Test.assertEqual(watchCountRows(api.outputs[0], "\nM,"), 66);
    Test.assertEqual(watchCountRows(api.outputs[0], "\nP,"), 9);
    Test.assert(api.stored.length() <= 24576);
    Test.assertEqual(api.stored.find("NP1,"), 0);
    Test.assertEqual(watchCountRows(api.stored, "\nM,"), 66);
    Test.assert(api.outputs[0].find("export_overflow") == null);
    System.println("WATCH_FIXTURE_BEGIN");
    System.println(c.state()["report"]);
    System.println("WATCH_FIXTURE_END");
    return true;
}
(:test)
function watchRecoveryDoesNotResume(logger) {
    var api = new WatchFakeApi();
    var c = newWatchTest(logger, api);
    if (c == null) {
        return false;
    }
    c.start(2);
    var recovered = newWatchTest(logger, api);
    Test.assertEqual(recovered.state()["running"], false);
    Test.assert(recovered.exportLast());
    Test.assertEqual(api.outputs[0].find("NP1,"), 0);
    Test.assert(api.outputs[0].find("F,incomplete,") != null);
    Test.assertEqual(api.registrations.size(), 1);
    c.stop("cancelled");
    return true;
}
(:test)
function watchCleanupFailuresStillAttemptAllResources(logger) {
    var api = new WatchFakeApi();
    var c = newWatchTest(logger, api);
    if (c == null) {
        return false;
    }
    c.start(2);
    api.failCleanup = true;
    c.stop("cancelled");
    c.stop("cancelled");
    Test.assertEqual(api.timerStops, 1);
    Test.assertEqual(api.hrStops, 1);
    Test.assertEqual(api.unregistrations, 1);
    Test.assertEqual(c.state()["errors"].size(), 3);
    return true;
}
(:test)
function watchUnsupportedRateFailsBeforeRegistration(logger) {
    var api = new WatchFakeApi();
    api.maxRate = 0;
    var c = newWatchTest(logger, api);
    if (c == null) {
        return false;
    }
    Test.assert(!c.start(2));
    Test.assertEqual(api.registrations.size(), 0);
    return true;
}
(:test)
function watchInvalidDurationDoesNotStart(logger) {
    var api = new WatchFakeApi();
    var c = newWatchTest(logger, api);
    if (c == null) {
        return false;
    }
    Test.assert(!c.start(3));
    Test.assertEqual(api.registrations.size(), 0);
    return true;
}

function watchCountRows(text, needle) {
    var count = 0;
    var remaining = text;
    while (remaining.find(needle) != null) {
        var at = remaining.find(needle);
        count += 1;
        remaining = remaining.substring(at + needle.length(), remaining.length());
    }
    return count;
}
(:test)
function watchRegisteredRelaysAndStartupCallback(logger) {
    var api = new WatchFakeApi();
    api.startupCallback = true;
    var c = newWatchTest(logger, api);
    if (c == null) {
        return false;
    }
    c.start(2);
    Test.assertEqual(c.state()["stats"]["hrSamples"], 0);
    api.hrCallbacks[0].invoke(65);
    api.dataCallbacks[0].invoke(null, [800, 900]);
    Test.assertEqual(c.state()["stats"]["hrSamples"], 1);
    assertNearMs(c.state()["rmssd"], 100);
    c.stop("cancelled");
    c.start(2);
    api.hrCallbacks[0].invoke(99);
    api.dataCallbacks[0].invoke(null, [800, 900]);
    api.now = 120000;
    api.timerCallbacks[0].invoke();
    Test.assertEqual(c.state()["stats"]["hrSamples"], 0);
    Test.assertEqual(api.vibes, 0);
    api.hrCallbacks[1].invoke(70);
    api.timerCallbacks[1].invoke();
    Test.assertEqual(api.vibes, 1);
    return true;
}

(:test)
function watchJournalSaveTimingAndContents(logger) {
    var api = new WatchFakeApi();
    var c = newWatchTest(logger, api);
    if (c == null) {
        return false;
    }
    c.start(2);
    Test.assertEqual(api.saves.size(), 1);
    Test.assert(api.stored.find("F,incomplete,") != null);
    api.hrCallbacks[0].invoke(65);
    api.dataCallbacks[0].invoke(
        { "x" => [1], "y" => [2], "z" => [1000], "timestamp" => [123] },
        [800, 900]
    );
    api.now = 60000;
    api.timerCallbacks[0].invoke();
    Test.assertEqual(api.saves.size(), 2);
    Test.assertEqual(watchCountRows(api.stored, "\nP,"), 4);
    Test.assertEqual(watchCountRows(api.stored, "\nM,"), 1);
    c.stop("cancelled");
    Test.assertEqual(api.saves.size(), 3);
    Test.assert(api.stored.find("F,cancelled,") != null);
    return true;
}

(:test)
function watchMemoryMinimumResetsBetweenSessions(logger) {
    var api = new WatchFakeApi();
    var c = newWatchTest(logger, api);
    if (c == null) {
        return false;
    }
    c.start(2);
    api.free = 100000;
    api.now = 60000;
    api.timerCallbacks[0].invoke();
    Test.assertEqual(c.journal.minutes[0][11], 100000);
    c.stop("cancelled");
    api.free = 500000;
    c.start(2);
    api.now = 120000;
    api.timerCallbacks[1].invoke();
    Test.assertEqual(c.journal.minutes[0][11], 500000);
    c.stop("cancelled");
    return true;
}

(:test)
function watchStartupFailureStagesPersist(logger) {
    var codes = ["rate_query_error", "hr_start_error", "data_start_error", "timer_start_error"];
    for (var i = 0; i < codes.size(); i += 1) {
        var api = new WatchFakeApi();
        api.failRate = i == 0;
        api.failHr = i == 1;
        api.failAllData = i == 2;
        api.failTimer = i == 3;
        var c = newWatchTest(logger, api);
        if (c == null) {
            return false;
        }
        Test.assert(!c.start(2));
        Test.assert(api.stored.find("E," + codes[i] + "\n") != null);
        var errors = c.state()["errors"];
        Test.assertEqual(errors[errors.size() - 1], codes[i]);
        Test.assert(c.exportLast());
        Test.assert(api.outputs[0].find("E," + codes[i] + "\n") != null);
        for (var j = 0; j < codes.size(); j += 1) {
            if (j != i) {
                Test.assert(api.stored.find("E," + codes[j] + "\n") == null);
                Test.assert(api.outputs[0].find("E," + codes[j] + "\n") == null);
            }
        }
        Test.assertEqual(api.vibes, 0);
        Test.assertEqual(api.timerStops, i == 3 ? 1 : 0);
        Test.assertEqual(api.hrStops, i == 0 ? 0 : 1);
        Test.assertEqual(api.unregistrations, i < 2 ? 0 : i == 2 ? 2 : 1);
    }
    var successApi = new WatchFakeApi();
    var success = newWatchTest(logger, successApi);
    if (success == null) {
        return false;
    }
    Test.assert(success.start(2));
    success.stop("cancelled");
    for (var k = 0; k < codes.size(); k += 1) {
        Test.assert(successApi.stored.find("E," + codes[k] + "\n") == null);
        Test.assert(successApi.outputs[0].find("E," + codes[k] + "\n") == null);
    }
    return true;
}
