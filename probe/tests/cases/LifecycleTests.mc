import Toybox.Test;

(:test)
function alarmWaitsForExactElapsedDeadline(logger) {
    var options = probeTestOptions();
    options["alarmDelayMs"] = 100;
    var platform = new ProbeTestPlatform();
    var p = newProbeForTest(logger, platform, options);
    if (p == null) {
        return false;
    }
    Test.assertEqual(p.start(1000, 1700000000), true);
    p.drain();
    p.tick(1099, 1700000001);
    Test.assertEqual(platform.vibrations, 0);
    p.tick(1100, 1700000001);
    Test.assertEqual(platform.vibrations, 1);
    var alarm = findProbeRecord(p, "alarm");
    Test.assertEqual(alarm["scheduledMs"], 1100);
    Test.assertEqual(alarm["actualMs"], 1100);
    return true;
}

(:test)
function delayedAlarmRecordsScheduledAndActualTimes(logger) {
    var options = probeTestOptions();
    options["alarmDelayMs"] = 100;
    var platform = new ProbeTestPlatform();
    var p = newProbeForTest(logger, platform, options);
    if (p == null) {
        return false;
    }
    p.start(1000, 1700000000);
    p.drain();
    p.tick(1300, 1700000001);
    Test.assertEqual(platform.vibrations, 1);
    var alarm = findProbeRecord(p, "alarm");
    Test.assertEqual(alarm["scheduledMs"], 1100);
    Test.assertEqual(alarm["actualMs"], 1300);
    Test.assertEqual(alarm["elapsedMs"], 1300);
    Test.assertEqual(alarm["wallSeconds"], 1700000001);
    return true;
}

(:test)
function repeatedTicksCannotDuplicateAlarm(logger) {
    var options = probeTestOptions();
    options["alarmDelayMs"] = 100;
    var platform = new ProbeTestPlatform();
    var p = runningProbeForTest(logger, platform, options);
    if (p == null) {
        return false;
    }
    p.tick(100, 1700000000);
    p.tick(100, 1700000000);
    p.tick(1000, 1700000001);
    Test.assertEqual(platform.vibrations, 1);
    Test.assertEqual(p.snapshot()["records"].size(), 1);
    return true;
}

(:test)
function wallClockChangesDoNotMoveAlarmDeadline(logger) {
    var options = probeTestOptions();
    options["alarmDelayMs"] = 100;
    var platform = new ProbeTestPlatform();
    var p = runningProbeForTest(logger, platform, options);
    if (p == null) {
        return false;
    }
    p.tick(99, 2000000000);
    Test.assertEqual(platform.vibrations, 0);
    p.tick(100, 1);
    Test.assertEqual(platform.vibrations, 1);
    Test.assertEqual(findProbeRecord(p, "alarm")["scheduledMs"], 100);
    Test.assertEqual(findProbeRecord(p, "alarm")["wallSeconds"], 1);
    return true;
}

(:test)
function alarmSurvivesSixtySixMinuteElapsedDeadline(logger) {
    var options = probeTestOptions();
    options["alarmDelayMs"] = 3960000;
    var platform = new ProbeTestPlatform();
    var p = newProbeForTest(logger, platform, options);
    if (p == null) {
        return false;
    }
    p.start(100, 1700000000);
    p.drain();
    p.tick(3960099, 1700003960);
    Test.assertEqual(platform.vibrations, 0);
    p.tick(3960100, 1700003960);
    Test.assertEqual(platform.vibrations, 1);
    Test.assertEqual(findProbeRecord(p, "alarm")["scheduledMs"], 3960100);
    return true;
}

(:test)
function cancellationSuppressesLateAlarms(logger) {
    var options = probeTestOptions();
    options["alarmDelayMs"] = 100;
    var platform = new ProbeTestPlatform();
    var p = runningProbeForTest(logger, platform, options);
    if (p == null) {
        return false;
    }
    p.stop(99, 1700000000, "cancelled");
    p.tick(100, 1700000000);
    p.tick(1000, 1700000001);
    Test.assertEqual(platform.vibrations, 0);
    Test.assertEqual(p.snapshot()["running"], false);
    Test.assertEqual(findProbeRecord(p, "stopped")["reason"], "cancelled");
    return true;
}

(:test)
function duplicateStartKeepsOriginalSessionDeadline(logger) {
    var options = probeTestOptions();
    options["alarmDelayMs"] = 100;
    var platform = new ProbeTestPlatform();
    var p = newProbeForTest(logger, platform, options);
    if (p == null) {
        return false;
    }
    p.start(1000, 1700000000);
    p.start(5000, 1700000004);
    Test.assertEqual(platform.sensorStarts, 1);
    Test.assertEqual(platform.timerStarts, 1);
    Test.assertEqual(p.snapshot()["deadlineMs"], 1100);
    return true;
}

(:test)
function stopReleasesResourcesExactlyOnce(logger) {
    var platform = new ProbeTestPlatform();
    var p = runningProbeForTest(logger, platform, probeTestOptions());
    if (p == null) {
        return false;
    }
    p.stop(100, 1700000000, "cancelled");
    p.stop(200, 1700000000, "interrupted");
    Test.assertEqual(platform.sensorStops, 1);
    Test.assertEqual(platform.timerStops, 1);
    Test.assertEqual(p.snapshot()["records"].size(), 1);
    Test.assertEqual(findProbeRecord(p, "stopped")["reason"], "cancelled");
    return true;
}

(:test)
function stoppedSessionIgnoresLateSensorCallbacks(logger) {
    var platform = new ProbeTestPlatform();
    var p = runningProbeForTest(logger, platform, probeTestOptions());
    if (p == null) {
        return false;
    }
    p.stop(100, 1700000000, "interrupted");
    p.drain();
    p.heartRate(200, 1700000000, 65);
    p.rr(200, 1700000000, [800, 900]);
    p.accelerometer(200, 1700000000, {
        "x" => [0],
        "y" => [0],
        "z" => [1000],
        "timestamp" => [200],
    });
    Test.assertEqual(p.snapshot()["records"].size(), 0);
    assertProbeCounter(p, "hrSamples", 0);
    assertProbeCounter(p, "accelSamples", 0);
    assertProbeCounter(p, "rrSamples", 0);
    Test.assertEqual(platform.sensorStarts, 1);
    Test.assertEqual(platform.timerStarts, 1);
    return true;
}

(:test)
function sensorStartupFailureCleansAttemptedResource(logger) {
    var platform = new ProbeTestPlatform();
    platform.failSensors = true;
    var p = newProbeForTest(logger, platform, probeTestOptions());
    if (p == null) {
        return false;
    }
    Test.assertEqual(p.start(0, 1700000000), false);
    Test.assertEqual(p.snapshot()["running"], false);
    Test.assertEqual(platform.sensorStarts, 1);
    Test.assertEqual(platform.sensorStops, 1);
    Test.assertEqual(platform.timerStarts, 0);
    findProbeRecord(p, "sensor_error");
    p.stop(100, 1700000000, "cancelled");
    Test.assertEqual(platform.sensorStops, 1);
    Test.assertEqual(platform.timerStops, 0);
    return true;
}

(:test)
function timerStartupFailureReleasesBothAttemptedResources(logger) {
    var platform = new ProbeTestPlatform();
    platform.failTimer = true;
    var p = newProbeForTest(logger, platform, probeTestOptions());
    if (p == null) {
        return false;
    }
    Test.assertEqual(p.start(0, 1700000000), false);
    Test.assertEqual(p.snapshot()["running"], false);
    Test.assertEqual(platform.sensorStarts, 1);
    Test.assertEqual(platform.timerStarts, 1);
    Test.assertEqual(platform.sensorStops, 1);
    Test.assertEqual(platform.timerStops, 1);
    findProbeRecord(p, "timer_error");
    p.stop(100, 1700000000, "cancelled");
    Test.assertEqual(platform.sensorStops, 1);
    Test.assertEqual(platform.timerStops, 1);
    return true;
}

(:test)
function configurationRejectsInvalidRecordCapacity(logger) {
    var badValues = [0, -1, 1.5, "3"];
    for (var i = 0; i < badValues.size(); i += 1) {
        var options = probeTestOptions();
        options["recordCapacity"] = badValues[i];
        if (!assertInvalidProbeOptions(logger, options)) {
            return false;
        }
    }
    return true;
}

(:test)
function configurationRejectsInvalidRrCapacity(logger) {
    var badValues = [0, 1, -1, 2.5, "30"];
    for (var i = 0; i < badValues.size(); i += 1) {
        var options = probeTestOptions();
        options["rrCapacity"] = badValues[i];
        if (!assertInvalidProbeOptions(logger, options)) {
            return false;
        }
    }
    return true;
}

(:test)
function configurationRejectsInvalidAlarmDelay(logger) {
    var badValues = [0, -1, 1.5, "100"];
    for (var i = 0; i < badValues.size(); i += 1) {
        var options = probeTestOptions();
        options["alarmDelayMs"] = badValues[i];
        if (!assertInvalidProbeOptions(logger, options)) {
            return false;
        }
    }
    return true;
}

(:test)
function configurationRejectsMissingRequiredOptions(logger) {
    if (!assertInvalidProbeOptions(logger, {})) {
        return false;
    }
    if (!assertInvalidProbeOptions(logger, { "recordCapacity" => 3, "rrCapacity" => 3 })) {
        return false;
    }
    if (!assertInvalidProbeOptions(logger, { "rrCapacity" => 3, "alarmDelayMs" => 100 })) {
        return false;
    }
    return assertInvalidProbeOptions(logger, { "recordCapacity" => 3, "alarmDelayMs" => 100 });
}

(:test)
function configurationAcceptsMinimumSupportedValues(logger) {
    var options = { "recordCapacity" => 1, "rrCapacity" => 2, "alarmDelayMs" => 1 };
    var platform = new ProbeTestPlatform();
    var p = runningProbeForTest(logger, platform, options);
    if (p == null) {
        return false;
    }
    p.rr(0, 1700000000, [800, 900]);
    assertNearMs(p.snapshot()["rmssdMs"], 100);
    Test.assertEqual(p.snapshot()["rrCount"], 2);
    Test.assertEqual(p.snapshot()["records"].size(), 1);
    Test.assertEqual(p.snapshot()["records"][0]["value"], 900);
    assertProbeCounter(p, "droppedRecords", 1);
    p.tick(1, 1700000000);
    Test.assertEqual(platform.vibrations, 1);
    Test.assertEqual(p.snapshot()["records"].size(), 1);
    Test.assertEqual(p.snapshot()["records"][0]["kind"], "alarm");
    assertProbeCounter(p, "droppedRecords", 2);
    return true;
}

(:test)
function successfulStartRecordsOriginWithoutGuessingOnset(logger) {
    var p = newProbeForTest(logger, new ProbeTestPlatform(), probeTestOptions());
    if (p == null) {
        return false;
    }
    Test.assertEqual(p.start(123, 1700000001), true);
    Test.assertEqual(p.snapshot()["running"], true);
    Test.assertEqual(p.snapshot()["deadlineMs"], 60123);
    var started = findProbeRecord(p, "started");
    Test.assertEqual(started["elapsedMs"], 123);
    Test.assertEqual(started["wallSeconds"], 1700000001);
    return true;
}
