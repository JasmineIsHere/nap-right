import Toybox.Lang;
class WatchFakeApi {
    var now = 0;
    var wall = 1700000000;
    var maxRate = 25;
    var registrations = [];
    var unregistrations = 0;
    var hrStops = 0;
    var timerStops = 0;
    var vibes = 0;
    var saves = [];
    var outputs = [];
    var failRr = false;
    var failRate = false;
    var failHr = false;
    var failAllData = false;
    var failTimer = false;
    var failCleanup = false;
    var failVibe = false;
    var failStorage = false;
    var stored = null;
    var mode = 0;
    var free = 500000;
    var hrCallbacks = [];
    var dataCallbacks = [];
    var timerCallbacks = [];
    var startupCallback = false;
    function rawTime() {
        return now;
    }
    function wallTime() {
        return wall;
    }
    function maximumRate() {
        if (failRate) {
            throw new Lang.Exception();
        }
        return maxRate;
    }
    function enableHr(callback) {
        if (failHr) {
            throw new Lang.Exception();
        }
        hrCallbacks.add(callback);
        if (startupCallback) {
            callback.invoke(99);
        }
    }
    function registerData(callback, rate, rrEnabled) {
        registrations.add([rate, rrEnabled]);
        dataCallbacks.add(callback);
        if (failAllData || (rrEnabled && failRr)) {
            throw new Lang.Exception();
        }
    }
    function unregisterData() {
        unregistrations += 1;
        if (failCleanup) {
            throw new Lang.Exception();
        }
    }
    function disableHr() {
        hrStops += 1;
        if (failCleanup) {
            throw new Lang.Exception();
        }
    }
    function startTimer(callback) {
        timerCallbacks.add(callback);
        if (failTimer) {
            throw new Lang.Exception();
        }
    }
    function stopTimer() {
        timerStops += 1;
        if (failCleanup) {
            throw new Lang.Exception();
        }
    }
    function vibrate() {
        vibes += 1;
        if (failVibe) {
            throw new Lang.Exception();
        }
    }
    function save(text) {
        if (failStorage) {
            throw new Lang.Exception();
        }
        stored = text;
        saves.add(text);
    }
    function load() {
        return stored;
    }
    function emit(text) {
        outputs.add(text);
    }
    function metrics() {
        return { "battery" => 800, "free" => free, "mode" => mode };
    }
    function metadata() {
        return ["test", "17.05", "5.2.0"];
    }
}
function newWatchTest(logger, api) {
    if (!(new WatchFactory() has :create)) {
        logger.error("WATCH_RED: factory missing");
        return null;
    }
    var factory = new WatchFactory();
    return watchInvoke(factory, api);
}
function watchInvoke(factory, api) {
    return factory.method(:create).invoke(api);
}
