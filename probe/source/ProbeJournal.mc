import Toybox.Lang;
class ProbeJournal {
    var header;
    var previews = [];
    var minutes = [];
    var counts = { "hr" => 0, "accel" => 0, "rr" => 0 };
    var errors = [];
    var alarm = null;
    var stats = null;
    function initialize(id, wall, metadata, rate, duration) {
        header =
            "NP1," +
            id +
            "," +
            duration +
            "," +
            rate +
            "," +
            wall +
            "," +
            metadata[0] +
            "," +
            metadata[1] +
            "," +
            metadata[2] +
            "\n";
    }
    function base(value) {
        if (value == null) {
            return "_";
        }
        var v = value.toLong();
        var sign = "";
        if (v < 0) {
            sign = "-";
            v = -v;
        }
        if (v == 0) {
            return "0";
        }
        var digits = "0123456789abcdefghijklmnopqrstuvwxyz";
        var out = "";
        while (v > 0) {
            var digit = (v % 36).toNumber();
            out = digits.substring(digit, digit + 1) + out;
            v = v / 36;
        }
        return sign + out;
    }
    function packed(values) {
        var out = "";
        for (var i = 0; i < values.size(); i += 1) {
            if (i > 0) {
                out += ",";
            }
            out += base(values[i]);
        }
        return out;
    }
    function observe(records) {
        for (var i = 0; i < records.size(); i += 1) {
            var r = records[i];
            var kind = r["kind"];
            if (kind.equals("alarm")) {
                alarm = [r["scheduledMs"], r["actualMs"]];
            }
            if (!counts.hasKey(kind) || counts[kind] >= 3) {
                continue;
            }
            counts[kind] += 1;
            var value = r["value"];
            var text = "_";
            if (value instanceof Lang.Array) {
                text = value[0] + ";" + value[1] + ";" + value[2];
            } else if (value != null) {
                text = value.toString();
            }
            previews.add(
                "P," +
                    kind +
                    "," +
                    base(r["elapsedMs"]) +
                    "," +
                    r["wallSeconds"] +
                    "," +
                    r["quality"] +
                    "," +
                    r["unit"] +
                    "," +
                    text +
                    "," +
                    base(r["sampleTimestampMs"]) +
                    "\n"
            );
        }
    }
    function report(reason, elapsed, totals) {
        var out = header;
        for (var i = 0; i < previews.size(); i += 1) {
            out += previews[i];
        }
        for (var i = 0; i < minutes.size(); i += 1) {
            out += "M," + packed(minutes[i]) + "\n";
        }
        for (var i = 0; i < errors.size(); i += 1) {
            out += "E," + errors[i] + "\n";
        }
        if (alarm != null) {
            out +=
                "A," +
                packed(alarm) +
                "," +
                (hasError("vibe_error") ? "vibe_error" : "requested") +
                "\n";
        }
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
        var values = "";
        for (var i = 0; i < names.size(); i += 1) {
            if (i > 0) {
                values += ":";
            }
            values += base(totals[names[i]]);
        }
        var rows = 1 + previews.size() + minutes.size() + errors.size() + (alarm == null ? 0 : 1);
        return out + "F," + reason + "," + base(elapsed) + "," + values + "," + rows + "\n";
    }
    function hasError(code) {
        for (var i = 0; i < errors.size(); i += 1) {
            if (errors[i].equals(code)) {
                return true;
            }
        }
        return false;
    }
    function error(code) {
        if (!hasError(code) && errors.size() < 8) {
            errors.add(code);
        }
    }
}
