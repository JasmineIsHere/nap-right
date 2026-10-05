import Toybox.Sensor;
import Toybox.System;
import Toybox.Time;
import Toybox.Timer;
import Toybox.Attention;
import Toybox.Application;
import Toybox.WatchUi;
import Toybox.Lang;
class GarminApi {
    var timer = new Timer.Timer();
    function rawTime() {
        return System.getTimer();
    }
    function wallTime() {
        return Time.now().value();
    }
    function maximumRate() {
        return Sensor.getMaxSampleRateForSensorType(:accelerometer);
    }
    function enableHr(callback) {
        if (!Sensor.enableSensorType(Sensor.SENSOR_HEARTRATE)) {
            throw new Lang.Exception();
        }
        Sensor.enableSensorEvents((new GarminHrBridge(callback)).method(:event));
    }
    function registerData(callback, rate, rrEnabled) {
        Sensor.registerSensorDataListener((new GarminDataBridge(callback)).method(:event), {
            :period => 1,
            :accelerometer => { :enabled => true, :sampleRate => rate, :includeTimestamps => true },
            :heartBeatIntervals => { :enabled => rrEnabled },
        });
    }
    function unregisterData() {
        Sensor.unregisterSensorDataListener();
    }
    function disableHr() {
        var failed = false;
        try {
            Sensor.enableSensorEvents(null);
        } catch (e) {
            failed = true;
        }
        try {
            Sensor.disableSensorType(Sensor.SENSOR_HEARTRATE);
        } catch (e) {
            failed = true;
        }
        if (failed) {
            throw new Lang.Exception();
        }
    }
    function startTimer(callback) {
        timer.start((new GarminTimerBridge(callback)).method(:event), 1000, true);
    }
    function stopTimer() {
        timer.stop();
    }
    function vibrate() {
        if (!(Attention has :vibrate)) {
            throw new Lang.Exception();
        }
        Attention.vibrate([
            new Attention.VibeProfile(50, 500),
            new Attention.VibeProfile(0, 500),
            new Attention.VibeProfile(50, 500),
        ]);
    }
    function save(text) {
        Application.Storage.setValue("sensorprobe-journal-v1", text);
    }
    function load() {
        return Application.Storage.getValue("sensorprobe-journal-v1");
    }
    function emit(text) {
        System.println(text);
    }
    function metrics() {
        var stats = System.getSystemStats();
        return {
            "battery" => (stats.battery * 10).toNumber(),
            "free" => stats.freeMemory,
            "mode" => System.getDisplayMode(),
        };
    }
    function version(parts) {
        var text = "";
        for (var i = 0; i < parts.size(); i += 1) {
            if (i > 0) {
                text += ".";
            }
            text += parts[i];
        }
        return text;
    }
    function metadata() {
        var settings = System.getDeviceSettings();
        return [
            "probe1",
            settings has :firmwareVersion ? version(settings.firmwareVersion) : "unknown",
            settings has :monkeyVersion ? version(settings.monkeyVersion) : "unknown",
        ];
    }
}
class GarminHrBridge {
    var callback;
    function initialize(c) {
        callback = c;
    }
    function event(info) {
        callback.invoke(info != null && info has :heartRate ? info.heartRate : null);
    }
}
class GarminDataBridge {
    var callback;
    function initialize(c) {
        callback = c;
    }
    function event(data) {
        var xyz = null;
        var rr = null;
        if (data != null && data has :accelerometerData && data.accelerometerData != null) {
            var a = data.accelerometerData;
            xyz = {
                "x" => a.x,
                "y" => a.y,
                "z" => a.z,
                "timestamp" => a has :timestamp ? a.timestamp : null,
            };
        }
        if (
            data != null &&
            data has :heartRateData &&
            data.heartRateData != null &&
            data.heartRateData has :heartBeatIntervals
        ) {
            rr = data.heartRateData.heartBeatIntervals;
        }
        callback.invoke(xyz, rr);
    }
}
class GarminTimerBridge {
    var callback;
    function initialize(c) {
        callback = c;
    }
    function event() {
        callback.invoke();
        if (System.getDisplayMode() == System.DISPLAY_MODE_HIGH_POWER) {
            WatchUi.requestUpdate();
        }
    }
}
