import Toybox.Test;

// Catches loss/conversion of capture timestamps, units, or the observed HR value.
(:test)
function hrPreservesUnitsAndCaptureTimes(logger) {
    var p = runningProbeForTest(logger, new ProbeTestPlatform(), probeTestOptions());
    if (p == null) {
        return false;
    }
    p.heartRate(310, 1700000001, 65);
    var r = p.snapshot()["records"][0];
    Test.assertEqual(r["kind"], "hr");
    Test.assertEqual(r["elapsedMs"], 310);
    Test.assertEqual(r["wallSeconds"], 1700000001);
    Test.assertEqual(r["unit"], "bpm");
    Test.assertEqual(r["value"], 65);
    Test.assertEqual(r["quality"], "valid");
    assertProbeCounter(p, "hrSamples", 1);
    return true;
}

// Catches substituting zero for unavailable HR or accepting zero as a measurement.
(:test)
function hrDistinguishesMissingFromZero(logger) {
    var p = runningProbeForTest(logger, new ProbeTestPlatform(), probeTestOptions());
    if (p == null) {
        return false;
    }
    p.heartRate(10, 1700000000, null);
    p.heartRate(20, 1700000000, 0);
    var records = p.snapshot()["records"];
    Test.assertEqual(records.size(), 2);
    Test.assertEqual(records[0]["quality"], "missing");
    Test.assertEqual(records[1]["quality"], "rejected");
    Test.assert(records[0]["value"] == null);
    Test.assert(records[1]["value"] == null);
    Test.assert(records[0]["reason"] != null);
    Test.assert(records[1]["reason"] != null);
    assertProbeCounter(p, "hrMissing", 1);
    assertProbeCounter(p, "hrRejected", 1);
    assertProbeCounter(p, "hrSamples", 0);
    return true;
}

(:test)
function hrRejectsNonnumericAndNegativeValues(logger) {
    var p = runningProbeForTest(logger, new ProbeTestPlatform(), probeTestOptions());
    if (p == null) {
        return false;
    }
    p.heartRate(10, 1700000000, "65");
    p.heartRate(20, 1700000000, -4);
    p.heartRate(30, 1700000000, 72);
    assertProbeCounter(p, "hrRejected", 2);
    assertProbeCounter(p, "hrSamples", 1);
    Test.assertEqual(p.snapshot()["records"][2]["value"], 72);
    return true;
}

// Catches collapsing XYZ into magnitude or confusing native and capture clocks.
(:test)
function accelPreservesAxesUnitsAndNativeTimestamps(logger) {
    var p = runningProbeForTest(logger, new ProbeTestPlatform(), probeTestOptions());
    if (p == null) {
        return false;
    }
    p.accelerometer(100, 1700000000, {
        "x" => [10, 20],
        "y" => [-30, -40],
        "z" => [1000, 990],
        "timestamp" => [8010, 8050],
    });
    var records = p.snapshot()["records"];
    Test.assertEqual(records.size(), 2);
    var r = records[1];
    Test.assertEqual(r["kind"], "accel");
    Test.assertEqual(r["unit"], "millig");
    Test.assertEqual(r["value"][0], 20);
    Test.assertEqual(r["value"][1], -40);
    Test.assertEqual(r["value"][2], 990);
    Test.assertEqual(r["sampleTimestampMs"], 8050);
    Test.assertEqual(r["elapsedMs"], 100);
    Test.assertEqual(r["wallSeconds"], 1700000000);
    Test.assertEqual(r["quality"], "valid");
    assertProbeCounter(p, "accelSamples", 2);
    return true;
}

(:test)
function accelDoesNotInventUnavailableSampleTimestamps(logger) {
    var p = runningProbeForTest(logger, new ProbeTestPlatform(), probeTestOptions());
    if (p == null) {
        return false;
    }
    p.accelerometer(100, 1700000000, {
        "x" => [1],
        "y" => [2],
        "z" => [1000],
        "timestamp" => null,
    });
    var r = p.snapshot()["records"][0];
    Test.assert(r["sampleTimestampMs"] == null);
    Test.assertEqual(r["value"][2], 1000);
    assertProbeCounter(p, "accelSamples", 1);
    return true;
}

(:test)
function accelRejectsUnequalAxesAtomically(logger) {
    var p = runningProbeForTest(logger, new ProbeTestPlatform(), probeTestOptions());
    if (p == null) {
        return false;
    }
    p.accelerometer(10, 1700000000, {
        "x" => [1, 2],
        "y" => [3],
        "z" => [1000, 1000],
        "timestamp" => [10, 20],
    });
    assertProbeCounter(p, "accelSamples", 0);
    assertProbeCounter(p, "accelRejected", 1);
    var r = p.snapshot()["records"][0];
    Test.assertEqual(r["quality"], "rejected");
    Test.assert(r["value"] == null);
    Test.assert(r["reason"] != null);
    return true;
}

(:test)
function accelRejectsMismatchedTimestampCount(logger) {
    var p = runningProbeForTest(logger, new ProbeTestPlatform(), probeTestOptions());
    if (p == null) {
        return false;
    }
    p.accelerometer(10, 1700000000, {
        "x" => [1, 2],
        "y" => [3, 4],
        "z" => [1000, 1000],
        "timestamp" => [10],
    });
    assertProbeCounter(p, "accelSamples", 0);
    assertProbeCounter(p, "accelRejected", 1);
    return true;
}

// Catches throwing away valid neighboring vectors or accepting a string axis.
(:test)
function accelRejectsOnlyInvalidVectorsInWellShapedBatch(logger) {
    var p = runningProbeForTest(logger, new ProbeTestPlatform(), probeTestOptions());
    if (p == null) {
        return false;
    }
    p.accelerometer(10, 1700000000, {
        "x" => [1, "bad", 3],
        "y" => [4, 5, 6],
        "z" => [1000, 1000, 1000],
        "timestamp" => [10, 20, 30],
    });
    assertProbeCounter(p, "accelSamples", 2);
    assertProbeCounter(p, "accelRejected", 1);
    var records = p.snapshot()["records"];
    Test.assertEqual(records[0]["value"][0], 1);
    Test.assertEqual(records[1]["quality"], "rejected");
    Test.assertEqual(records[2]["value"][0], 3);
    Test.assertEqual(records[2]["sampleTimestampMs"], 30);
    return true;
}

(:test)
function accelMissingBatchIsExplicit(logger) {
    var p = runningProbeForTest(logger, new ProbeTestPlatform(), probeTestOptions());
    if (p == null) {
        return false;
    }
    p.accelerometer(10, 1700000000, null);
    assertProbeCounter(p, "accelMissing", 1);
    assertProbeCounter(p, "accelSamples", 0);
    var r = p.snapshot()["records"][0];
    Test.assertEqual(r["quality"], "missing");
    Test.assert(r["value"] == null);
    return true;
}

(:test)
function accelEmptyBatchDoesNotBecomeStillnessEvidence(logger) {
    var p = runningProbeForTest(logger, new ProbeTestPlatform(), probeTestOptions());
    if (p == null) {
        return false;
    }
    p.accelerometer(10, 1700000000, { "x" => [], "y" => [], "z" => [], "timestamp" => [] });
    assertProbeCounter(p, "accelSamples", 0);
    assertProbeCounter(p, "accelRejected", 0);
    Test.assertEqual(p.snapshot()["records"].size(), 0);
    return true;
}

(:test)
function rrPreservesMillisecondsAndCaptureTimes(logger) {
    var p = runningProbeForTest(logger, new ProbeTestPlatform(), probeTestOptions());
    if (p == null) {
        return false;
    }
    p.rr(123, 1700000001, [810]);
    var r = p.snapshot()["records"][0];
    Test.assertEqual(r["kind"], "rr");
    Test.assertEqual(r["unit"], "ms");
    Test.assertEqual(r["value"], 810);
    Test.assertEqual(r["elapsedMs"], 123);
    Test.assertEqual(r["wallSeconds"], 1700000001);
    Test.assertEqual(r["quality"], "valid");
    assertProbeCounter(p, "rrSamples", 1);
    return true;
}

(:test)
function accelRejectsMissingAxisWithoutFabricatingSamples(logger) {
    var p = runningProbeForTest(logger, new ProbeTestPlatform(), probeTestOptions());
    if (p == null) {
        return false;
    }
    p.accelerometer(10, 1700000000, { "x" => [1], "z" => [1000], "timestamp" => [10] });
    assertProbeCounter(p, "accelSamples", 0);
    assertProbeCounter(p, "accelRejected", 1);
    var r = p.snapshot()["records"][0];
    Test.assertEqual(r["quality"], "rejected");
    Test.assert(r["value"] == null);
    return true;
}
