import Toybox.Test;
import Toybox.Sensor;
(:test)
function garminHrUsesOnboardSensorAndForwardsReadings(logger) {
    var api = new GarminHrTestApi();
    var receiver = new GarminHrTestReceiver();
    api.enableHr(receiver.method(:receive));
    Test.assertEqual(api.enabled.size(), 1);
    Test.assertEqual(api.enabled[0], Sensor.SENSOR_ONBOARD_HEARTRATE);
    Test.assertEqual(api.listeners.size(), 1);
    api.listeners[0].invoke(new GarminHrTestInfo());
    Test.assertEqual(receiver.value, 68);
    api.disableHr();
    Test.assertEqual(api.disabled.size(), 1);
    Test.assertEqual(api.disabled[0], Sensor.SENSOR_ONBOARD_HEARTRATE);
    Test.assertEqual(api.listeners.size(), 2);
    Test.assert(api.listeners[1] == null);
    return true;
}
(:test)
function garminHrUnavailableStillCleansOnboardAttempt(logger) {
    var api = new GarminHrTestApi();
    var receiver = new GarminHrTestReceiver();
    api.available = false;
    var threw = false;
    try {
        api.enableHr(receiver.method(:receive));
    } catch (e) {
        threw = true;
    }
    Test.assert(threw);
    Test.assertEqual(api.enabled.size(), 1);
    Test.assertEqual(api.enabled[0], Sensor.SENSOR_ONBOARD_HEARTRATE);
    Test.assertEqual(api.listeners.size(), 0);
    api.disableHr();
    Test.assertEqual(api.disabled[0], Sensor.SENSOR_ONBOARD_HEARTRATE);
    Test.assert(api.listeners[0] == null);
    return true;
}
(:test)
function garminHrEventFailureCleansBothResources(logger) {
    var api = new GarminHrTestApi();
    var receiver = new GarminHrTestReceiver();
    api.failEvents = true;
    var threw = false;
    try {
        api.enableHr(receiver.method(:receive));
    } catch (e) {
        threw = true;
    }
    Test.assert(threw);
    api.disableHr();
    Test.assertEqual(api.disabled[0], Sensor.SENSOR_ONBOARD_HEARTRATE);
    Test.assertEqual(api.listeners.size(), 2);
    Test.assert(api.listeners[1] == null);
    return true;
}

(:test)
function garminHrCleanupFailuresRemainIndependent(logger) {
    for (var i = 0; i < 2; i += 1) {
        var api = new GarminHrTestApi();
        var receiver = new GarminHrTestReceiver();
        api.enableHr(receiver.method(:receive));
        api.failUnregister = i == 0;
        api.failDisable = i == 1;
        var threw = false;
        try {
            api.disableHr();
        } catch (e) {
            threw = true;
        }
        Test.assert(threw);
        Test.assertEqual(api.listeners.size(), 2);
        Test.assert(api.listeners[1] == null);
        Test.assertEqual(api.disabled.size(), 1);
        Test.assertEqual(api.disabled[0], Sensor.SENSOR_ONBOARD_HEARTRATE);
    }
    return true;
}
