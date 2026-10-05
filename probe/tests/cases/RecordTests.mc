import Toybox.Test;

(:test)
function recordsEvictOldestWithExactDropCount(logger) {
    var options = probeTestOptions();
    options["recordCapacity"] = 3;
    var p = runningProbeForTest(logger, new ProbeTestPlatform(), options);
    if (p == null) {
        return false;
    }
    p.heartRate(10, 1700000000, 61);
    p.heartRate(20, 1700000000, 62);
    p.heartRate(30, 1700000000, 63);
    p.heartRate(40, 1700000000, 64);
    var records = p.snapshot()["records"];
    Test.assertEqual(records.size(), 3);
    Test.assertEqual(records[0]["value"], 62);
    Test.assertEqual(records[1]["elapsedMs"], 30);
    Test.assertEqual(records[2]["value"], 64);
    assertProbeCounter(p, "droppedRecords", 1);
    assertProbeCounter(p, "hrSamples", 4);
    return true;
}

(:test)
function drainPreservesLifetimeCountersAndRrHistory(logger) {
    var p = runningProbeForTest(logger, new ProbeTestPlatform(), probeTestOptions());
    if (p == null) {
        return false;
    }
    p.rr(100, 1700000000, [800, 900]);
    var records = p.drain();
    Test.assertEqual(records.size(), 2);
    Test.assertEqual(records[0]["value"], 800);
    Test.assertEqual(records[1]["value"], 900);
    Test.assertEqual(p.snapshot()["records"].size(), 0);
    Test.assertEqual(p.drain().size(), 0);
    assertProbeCounter(p, "rrSamples", 2);
    Test.assertEqual(p.snapshot()["rrCount"], 2);
    assertNearMs(p.snapshot()["rmssdMs"], 100);
    return true;
}

(:test)
function snapshotCannotMutateNestedInternalRecords(logger) {
    var p = runningProbeForTest(logger, new ProbeTestPlatform(), probeTestOptions());
    if (p == null) {
        return false;
    }
    p.accelerometer(10, 1700000000, { "x" => [1], "y" => [2], "z" => [1000], "timestamp" => [10] });
    var snapshot = p.snapshot();
    snapshot["records"][0]["value"][0] = 999;
    snapshot["records"][0]["elapsedMs"] = 999;
    snapshot["stats"]["accelSamples"] = 999;
    var actual = p.snapshot();
    Test.assertEqual(actual["records"][0]["value"][0], 1);
    Test.assertEqual(actual["records"][0]["elapsedMs"], 10);
    assertProbeCounter(p, "accelSamples", 1);
    return true;
}

(:test)
function drainCannotMutateRetainedRrHistory(logger) {
    var p = runningProbeForTest(logger, new ProbeTestPlatform(), probeTestOptions());
    if (p == null) {
        return false;
    }
    p.rr(100, 1700000000, [800, 900]);
    var records = p.drain();
    records[0]["value"] = 9999;
    p.rr(200, 1700000000, [800]);
    assertNearMs(p.snapshot()["rmssdMs"], 100);
    assertProbeCounter(p, "rrSamples", 3);
    return true;
}

(:test)
function oversizedAccelBatchStillUsesBoundedRecordStorage(logger) {
    var options = probeTestOptions();
    options["recordCapacity"] = 3;
    var p = runningProbeForTest(logger, new ProbeTestPlatform(), options);
    if (p == null) {
        return false;
    }
    var x = [];
    var y = [];
    var z = [];
    for (var i = 0; i < 40; i += 1) {
        x.add(i);
        y.add(0);
        z.add(1000);
    }
    p.accelerometer(100, 1700000000, { "x" => x, "y" => y, "z" => z, "timestamp" => null });
    var records = p.snapshot()["records"];
    Test.assertEqual(records.size(), 3);
    Test.assertEqual(records[0]["value"][0], 37);
    Test.assertEqual(records[2]["value"][0], 39);
    assertProbeCounter(p, "accelSamples", 40);
    assertProbeCounter(p, "droppedRecords", 37);
    return true;
}

// 2000 callbacks spaced 2 s span almost 66 min; each contributes 5 signal records.
(:test)
function longSessionBoundsRecordsAndRrWithoutLosingCounters(logger) {
    var options = probeTestOptions();
    options["recordCapacity"] = 7;
    options["rrCapacity"] = 5;
    options["alarmDelayMs"] = 4000000;
    var platform = new ProbeTestPlatform();
    var p = runningProbeForTest(logger, platform, options);
    if (p == null) {
        return false;
    }
    for (var i = 0; i < 2000; i += 1) {
        var at = i * 2000;
        p.heartRate(at, 1700000000 + i * 2, 60);
        p.accelerometer(at, 1700000000 + i * 2, {
            "x" => [0, 1],
            "y" => [0, 0],
            "z" => [1000, 1000],
            "timestamp" => null,
        });
        p.rr(at, 1700000000 + i * 2, [800, 900]);
        p.tick(at, 1700000000 + i * 2);
    }
    var snapshot = p.snapshot();
    Test.assertEqual(snapshot["records"].size(), 7);
    Test.assertEqual(snapshot["rrCount"], 5);
    Test.assertEqual(snapshot["records"][6]["elapsedMs"], 3998000);
    assertProbeCounter(p, "hrSamples", 2000);
    assertProbeCounter(p, "accelSamples", 4000);
    assertProbeCounter(p, "rrSamples", 4000);
    assertProbeCounter(p, "droppedRecords", 9993);
    assertNearMs(snapshot["rmssdMs"], 100);
    Test.assertEqual(platform.vibrations, 0);
    return true;
}

(:test)
function drainPreservesInterleavedSignalOrderAndTimes(logger) {
    var p = runningProbeForTest(logger, new ProbeTestPlatform(), probeTestOptions());
    if (p == null) {
        return false;
    }
    p.heartRate(10, 1700000000, 65);
    p.accelerometer(20, 1700000001, {
        "x" => [1],
        "y" => [2],
        "z" => [1000],
        "timestamp" => [8020],
    });
    p.rr(30, 1700000002, [800, 900]);
    var records = p.drain();
    Test.assertEqual(records.size(), 4);
    Test.assertEqual(records[0]["kind"], "hr");
    Test.assertEqual(records[1]["kind"], "accel");
    Test.assertEqual(records[2]["kind"], "rr");
    Test.assertEqual(records[3]["kind"], "rr");
    Test.assertEqual(records[0]["elapsedMs"], 10);
    Test.assertEqual(records[1]["elapsedMs"], 20);
    Test.assertEqual(records[2]["elapsedMs"], 30);
    Test.assertEqual(records[3]["wallSeconds"], 1700000002);
    Test.assertEqual(records[2]["value"], 800);
    Test.assertEqual(records[3]["value"], 900);
    return true;
}
