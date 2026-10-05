import Toybox.Lang;
import Toybox.Math;

// Platform-independent M0 diagnostics. Capture times are supplied by the adapter.
class ProbeSession {
    private var _platform;
    private var _capacity;
    private var _rrCapacity;
    private var _delay;
    private var _records;
    private var _rr;
    private var _stats;
    private var _running = false;
    private var _started = false;
    private var _deadline = null;
    private var _alarmed = false;
    private var _sensorsAttempted = false;
    private var _timerAttempted = false;

    function initialize(options, platform) {
        _platform = platform;
        _capacity = options["recordCapacity"];
        _rrCapacity = options["rrCapacity"];
        _delay = options["alarmDelayMs"];
        _records = [];
        _rr = [];
        _stats = {};
        var names = [
            "hrSamples",
            "hrMissing",
            "hrRejected",
            "accelSamples",
            "accelMissing",
            "accelRejected",
            "rrSamples",
            "rrMissingCallbacks",
            "rrRejected",
            "droppedRecords",
            "rrGaps",
        ];
        for (var i = 0; i < names.size(); i += 1) {
            _stats[names[i]] = 0;
        }
    }

    function start(at, wall) {
        if (_started) {
            return _running;
        }
        _started = true;
        _deadline = at + _delay;
        var failureKind = "sensor_error";
        try {
            _sensorsAttempted = true;
            _platform.startSensors();
            failureKind = "timer_error";
            _timerAttempted = true;
            _platform.startTimer();
        } catch (e) {
            cleanup();
            append(record(failureKind, at, wall));
            return false;
        }
        _running = true;
        append(record("started", at, wall));
        return true;
    }

    // Clear flags before calling the adapter; each attempted resource is released once.
    private function cleanup() {
        if (_timerAttempted) {
            _timerAttempted = false;
            try {
                _platform.stopTimer();
            } catch (e) {}
        }
        if (_sensorsAttempted) {
            _sensorsAttempted = false;
            try {
                _platform.stopSensors();
            } catch (e) {}
        }
    }

    function stop(at, wall, reason) {
        if (!_running) {
            return;
        }
        _running = false;
        cleanup();
        var r = record("stopped", at, wall);
        r["reason"] = reason;
        append(r);
    }

    function tick(at, wall) {
        if (!_running || _alarmed || at < _deadline) {
            return;
        }
        _alarmed = true;
        var r = record("alarm", at, wall);
        r["scheduledMs"] = _deadline;
        r["actualMs"] = at;
        append(r);
        _platform.vibrate();
    }

    private function numeric(value) {
        return (
            value instanceof Lang.Number ||
            value instanceof Lang.Long ||
            value instanceof Lang.Float ||
            value instanceof Lang.Double
        );
    }

    private function positive(value) {
        return numeric(value) && value > 0;
    }

    function heartRate(at, wall, value) {
        if (!_running) {
            return;
        }
        var quality = value == null ? "missing" : positive(value) ? "valid" : "rejected";
        var counter = quality.equals("valid")
            ? "hrSamples"
            : quality.equals("missing")
              ? "hrMissing"
              : "hrRejected";
        _stats[counter] += 1;
        append(signal("hr", at, wall, "bpm", value, quality));
    }

    function accelerometer(at, wall, payload) {
        if (!_running) {
            return;
        }
        if (payload == null) {
            _stats["accelMissing"] += 1;
            append(signal("accel", at, wall, "millig", null, "missing"));
            return;
        }
        var shaped = payload instanceof Lang.Dictionary;
        var x = shaped ? payload["x"] : null;
        var y = shaped ? payload["y"] : null;
        var z = shaped ? payload["z"] : null;
        var times = shaped ? payload["timestamp"] : null;
        shaped = x instanceof Lang.Array && y instanceof Lang.Array && z instanceof Lang.Array;
        if (shaped) {
            shaped = x.size() == y.size() && x.size() == z.size();
            if (times != null) {
                shaped = shaped && times instanceof Lang.Array;
                if (shaped) {
                    shaped = times.size() == x.size();
                }
            }
        }
        if (!shaped) {
            _stats["accelRejected"] += 1;
            append(signal("accel", at, wall, "millig", null, "rejected"));
            return;
        }
        for (var i = 0; i < x.size(); i += 1) {
            var valid = numeric(x[i]) && numeric(y[i]) && numeric(z[i]);
            var counter = valid ? "accelSamples" : "accelRejected";
            _stats[counter] += 1;
            var r = signal(
                "accel",
                at,
                wall,
                "millig",
                valid ? [x[i], y[i], z[i]] : null,
                valid ? "valid" : "rejected"
            );
            r["sampleTimestampMs"] = times == null ? null : times[i];
            append(r);
        }
    }

    function rr(at, wall, intervals) {
        if (!_running) {
            return;
        }
        if (intervals == null) {
            _rr = [];
            _stats["rrMissingCallbacks"] += 1;
            append(signal("rr", at, wall, "ms", null, "missing"));
            return;
        }
        for (var i = 0; i < intervals.size(); i += 1) {
            var valid = positive(intervals[i]);
            var counter = valid ? "rrSamples" : "rrRejected";
            _stats[counter] += 1;
            if (valid) {
                if (_rr.size() == _rrCapacity) {
                    _rr = _rr.slice(1, _rr.size());
                }
                _rr.add(intervals[i]);
            } else {
                _rr = [];
            }
            append(signal("rr", at, wall, "ms", intervals[i], valid ? "valid" : "rejected"));
        }
    }

    function rrGap(at, wall) {
        if (!_running) {
            return;
        }
        _rr = [];
        _stats["rrGaps"] += 1;
        var r = record("rr_gap", at, wall);
        r["reason"] = "callback_gap";
        append(r);
    }

    private function rmssd() {
        if (_rr.size() < 2) {
            return null;
        }
        var sum = 0.0d;
        for (var i = 1; i < _rr.size(); i += 1) {
            var difference = _rr[i].toDouble() - _rr[i - 1].toDouble();
            sum += difference * difference;
        }
        return Math.sqrt(sum / (_rr.size() - 1));
    }

    private function record(kind, at, wall) {
        return { "kind" => kind, "elapsedMs" => at, "wallSeconds" => wall };
    }

    private function signal(kind, at, wall, unit, value, quality) {
        var r = record(kind, at, wall);
        r["unit"] = unit;
        r["quality"] = quality;
        r["value"] = quality.equals("valid") ? value : null;
        if (!quality.equals("valid")) {
            r["reason"] = quality.equals("missing") ? "unavailable" : "invalid_value";
        }
        return r;
    }

    private function append(r) {
        if (_records.size() == _capacity) {
            _records = _records.slice(1, _records.size());
            _stats["droppedRecords"] += 1;
        }
        _records.add(r);
    }

    private function copy(value) {
        if (value instanceof Lang.Array) {
            var result = [];
            for (var i = 0; i < value.size(); i += 1) {
                result.add(copy(value[i]));
            }
            return result;
        }
        if (value instanceof Lang.Dictionary) {
            var result = {};
            var keys = value.keys();
            for (var i = 0; i < keys.size(); i += 1) {
                result[keys[i]] = copy(value[keys[i]]);
            }
            return result;
        }
        return value;
    }

    function snapshot() {
        return {
            "records" => copy(_records),
            "stats" => copy(_stats),
            "rmssdMs" => rmssd(),
            "rrCount" => _rr.size(),
            "running" => _running,
            "deadlineMs" => _deadline,
        };
    }

    function drain() {
        var records = _records;
        _records = [];
        return records;
    }
}
