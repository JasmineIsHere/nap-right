import Toybox.Lang;

class ProbeFactory {
    function create(options, platform) {
        if (!(options instanceof Lang.Dictionary)) {
            throw new Lang.Exception();
        }
        var minima = { "recordCapacity" => 1, "rrCapacity" => 2, "alarmDelayMs" => 1 };
        var keys = minima.keys();
        for (var i = 0; i < keys.size(); i += 1) {
            var value = options[keys[i]];
            if (!(value instanceof Lang.Number) || value < minima[keys[i]]) {
                throw new Lang.Exception();
            }
        }
        return new ProbeSession(options, platform);
    }
}
