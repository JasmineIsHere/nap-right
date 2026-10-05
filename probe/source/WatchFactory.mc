class WatchFactory {
    function create(api) {
        return new ProbeController(api);
    }
}
class ProbeClock {
    var api;
    var origin;
    function initialize(driver) {
        api = driver;
        origin = unsigned(api.rawTime());
    }
    function unsigned(value) {
        var v = value.toLong();
        if (v < 0) {
            v += 4294967296l;
        }
        return v;
    }
    function elapsed() {
        var delta = unsigned(api.rawTime()) - origin;
        if (delta < 0) {
            delta += 4294967296l;
        }
        return delta.toNumber();
    }
}
class ProbeRelay {
    var controller;
    var generation;
    function initialize(c, g) {
        controller = c;
        generation = g;
    }
    function hr(value) {
        controller.onHr(generation, value);
    }
    function data(payload, rr) {
        controller.onData(generation, payload, rr);
    }
    function timer() {
        controller.onTick(generation);
    }
}
class ProbePlatform {
    var api;
    var relay;
    var owner;
    var hrAttempted = false;
    var dataAttempted = false;
    var timerAttempted = false;
    function initialize(driver, r, c) {
        api = driver;
        relay = r;
        owner = c;
    }
    function startSensors() {
        var maximum = api.maximumRate();
        if (maximum < 1) {
            owner.error("accel_unavailable");
            throw new Toybox.Lang.Exception();
        }
        owner.rate = maximum < 25 ? maximum : 25;
        hrAttempted = true;
        api.enableHr(relay.method(:hr));
        dataAttempted = true;
        try {
            api.registerData(relay.method(:data), owner.rate, true);
        } catch (e) {
            owner.error("rr_registration");
            dataAttempted = false;
            try {
                api.unregisterData();
            } catch (cleanupError) {
                owner.error("data_cleanup");
                throw cleanupError;
            }
            owner.rrEnabled = false;
            dataAttempted = true;
            api.registerData(relay.method(:data), owner.rate, false);
        }
    }
    function startTimer() {
        timerAttempted = true;
        api.startTimer(relay.method(:timer));
    }
    function stopTimer() {
        if (timerAttempted) {
            timerAttempted = false;
            try {
                api.stopTimer();
            } catch (e) {
                owner.error("timer_cleanup");
            }
        }
    }
    function stopSensors() {
        if (dataAttempted) {
            dataAttempted = false;
            try {
                api.unregisterData();
            } catch (e) {
                owner.error("data_cleanup");
            }
        }
        if (hrAttempted) {
            hrAttempted = false;
            try {
                api.disableHr();
            } catch (e) {
                owner.error("hr_cleanup");
            }
        }
    }
    function vibrate() {
        try {
            api.vibrate();
        } catch (e) {
            owner.error("vibe_error");
        }
    }
}
