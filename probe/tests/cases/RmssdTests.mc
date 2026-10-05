import Toybox.Test;

// Independently calculated: two successive differences have magnitude 100 ms.
(:test)
function rmssdMatchesKnownAlternatingIntervals(logger) {
    var p = runningProbeForTest(logger, new ProbeTestPlatform(), probeTestOptions());
    if (p == null) {
        return false;
    }
    p.rr(100, 1700000000, [800, 900, 800]);
    assertNearMs(p.snapshot()["rmssdMs"], 100);
    Test.assertEqual(p.snapshot()["rrCount"], 3);
    return true;
}

(:test)
function rmssdKeepsMeasuredZeroDistinctFromNull(logger) {
    var p = runningProbeForTest(logger, new ProbeTestPlatform(), probeTestOptions());
    if (p == null) {
        return false;
    }
    p.rr(100, 1700000000, [800, 800, 800]);
    assertNearMs(p.snapshot()["rmssdMs"], 0);
    return true;
}

(:test)
function rmssdRequiresTwoConsecutiveIntervals(logger) {
    var p = runningProbeForTest(logger, new ProbeTestPlatform(), probeTestOptions());
    if (p == null) {
        return false;
    }
    p.rr(100, 1700000000, [800]);
    Test.assert(p.snapshot()["rmssdMs"] == null);
    Test.assertEqual(p.snapshot()["rrCount"], 1);
    return true;
}

(:test)
function rrMissingCallbackDoesNotInventMissingBeats(logger) {
    var p = runningProbeForTest(logger, new ProbeTestPlatform(), probeTestOptions());
    if (p == null) {
        return false;
    }
    p.rr(100, 1700000000, [800, 900]);
    p.rr(10000, 1700000010, null);
    assertProbeCounter(p, "rrMissingCallbacks", 1);
    assertProbeCounter(p, "rrRejected", 0);
    assertProbeCounter(p, "rrSamples", 2);
    Test.assert(p.snapshot()["rmssdMs"] == null);
    Test.assertEqual(p.snapshot()["rrCount"], 0);
    var records = p.snapshot()["records"];
    Test.assertEqual(records[2]["quality"], "missing");
    Test.assert(records[2]["value"] == null);
    return true;
}

// New segment differs by 200; including any pre-gap interval gives the wrong value.
(:test)
function rmssdDoesNotBridgeUnavailableCallbacks(logger) {
    var p = runningProbeForTest(logger, new ProbeTestPlatform(), probeTestOptions());
    if (p == null) {
        return false;
    }
    p.rr(10, 1700000000, [800, 900]);
    p.rr(20, 1700000000, null);
    p.rr(30, 1700000000, [1000, 1200]);
    assertNearMs(p.snapshot()["rmssdMs"], 200);
    Test.assertEqual(p.snapshot()["rrCount"], 2);
    return true;
}

(:test)
function rmssdDoesNotBridgeRejectedIntervals(logger) {
    var p = runningProbeForTest(logger, new ProbeTestPlatform(), probeTestOptions());
    if (p == null) {
        return false;
    }
    p.rr(100, 1700000000, [800, -1, 1000, 1300]);
    assertNearMs(p.snapshot()["rmssdMs"], 300);
    Test.assertEqual(p.snapshot()["rrCount"], 2);
    assertProbeCounter(p, "rrSamples", 3);
    assertProbeCounter(p, "rrRejected", 1);
    return true;
}

(:test)
function rrRejectsZeroAndNumericStrings(logger) {
    var p = runningProbeForTest(logger, new ProbeTestPlatform(), probeTestOptions());
    if (p == null) {
        return false;
    }
    p.rr(100, 1700000000, [800, 0, "900", 1000]);
    Test.assert(p.snapshot()["rmssdMs"] == null);
    Test.assertEqual(p.snapshot()["rrCount"], 1);
    assertProbeCounter(p, "rrRejected", 2);
    assertProbeCounter(p, "rrSamples", 2);
    return true;
}

// Last three intervals: 1100,900,1200; sqrt((200^2+300^2)/2) = 254.950975679.
(:test)
function rmssdUsesOnlyTheBoundedRecentWindow(logger) {
    var options = probeTestOptions();
    options["rrCapacity"] = 3;
    var p = runningProbeForTest(logger, new ProbeTestPlatform(), options);
    if (p == null) {
        return false;
    }
    p.rr(100, 1700000000, [1000, 1100, 900, 1200]);
    assertNearMs(p.snapshot()["rmssdMs"], 254.950975679);
    Test.assertEqual(p.snapshot()["rrCount"], 3);
    assertProbeCounter(p, "rrSamples", 4);
    return true;
}

(:test)
function rmssdContinuesAcrossValidCallbackBoundaries(logger) {
    var p = runningProbeForTest(logger, new ProbeTestPlatform(), probeTestOptions());
    if (p == null) {
        return false;
    }
    p.rr(100, 1700000000, [800]);
    p.rr(200, 1700000000, [900, 800]);
    assertNearMs(p.snapshot()["rmssdMs"], 100);
    Test.assertEqual(p.snapshot()["rrCount"], 3);
    return true;
}
