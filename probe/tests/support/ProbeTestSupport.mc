import Toybox.Lang;
import Toybox.Test;

// Hardware side effects only. The real probe must own all recording and decisions.
class ProbeTestPlatform {
    var sensorStarts;
    var timerStarts;
    var sensorStops;
    var timerStops;
    var vibrations;
    var failSensors;
    var failTimer;

    function initialize() {
        sensorStarts = 0;
        timerStarts = 0;
        sensorStops = 0;
        timerStops = 0;
        vibrations = 0;
        failSensors = false;
        failTimer = false;
    }

    function startSensors() {
        sensorStarts += 1;
        if (failSensors) {
            throw new Lang.Exception();
        }
    }

    function startTimer() {
        timerStarts += 1;
        if (failTimer) {
            throw new Lang.Exception();
        }
    }

    function stopSensors() {
        sensorStops += 1;
    }
    function stopTimer() {
        timerStops += 1;
    }
    function vibrate() {
        vibrations += 1;
    }
}

function probeTestOptions() {
    return { "recordCapacity" => 64, "rrCapacity" => 30, "alarmDelayMs" => 60000 };
}

function probeFactoryAvailable(logger) {
    var factory = new ProbeFactory();
    if (!(factory has :create)) {
        logger.error("M0_RED: ProbeFactory.create is not implemented");
        return false;
    }
    return true;
}

// Opaque parameter preserves runtime lookup, which the compiler would otherwise bind.
function invokeProbeFactory(factory, options, platform) {
    return factory.method(:create).invoke(options, platform);
}

function newProbeForTest(logger, platform, options) {
    if (!probeFactoryAvailable(logger)) {
        return null;
    }
    var probe = invokeProbeFactory(new ProbeFactory(), options, platform);
    Test.assertMessage(probe != null, "Implemented factory returned no probe");
    return probe;
}

function runningProbeForTest(logger, platform, options) {
    var probe = newProbeForTest(logger, platform, options);
    if (probe == null) {
        return null;
    }
    Test.assertEqual(probe.start(0, 1700000000), true);
    probe.drain();
    return probe;
}

function assertProbeCounter(probe, key, expected) {
    Test.assertEqual(probe.snapshot()["stats"][key], expected);
}

function assertNearMs(actual, expected) {
    Test.assertMessage(actual != null, "Expected a measured RMSSD, not null");
    Test.assertMessage(
        actual >= expected - 0.001 && actual <= expected + 0.001,
        "RMSSD differs from hand-calculated fixture"
    );
}

function findProbeRecord(probe, kind) {
    var records = probe.snapshot()["records"];
    for (var i = 0; i < records.size(); i += 1) {
        if (records[i]["kind"].equals(kind)) {
            return records[i];
        }
    }
    Test.assertMessage(false, "Expected diagnostic record is absent: " + kind);
    return null;
}

function assertInvalidProbeOptions(logger, options) {
    if (!probeFactoryAvailable(logger)) {
        return false;
    }
    var platform = new ProbeTestPlatform();
    var rejected = false;
    try {
        invokeProbeFactory(new ProbeFactory(), options, platform);
    } catch (e) {
        rejected = true;
    }
    Test.assertMessage(rejected, "Invalid probe options must be rejected");
    Test.assertEqual(platform.sensorStarts, 0);
    Test.assertEqual(platform.timerStarts, 0);
    Test.assertEqual(platform.sensorStops, 0);
    Test.assertEqual(platform.timerStops, 0);
    Test.assertEqual(platform.vibrations, 0);
    return true;
}
