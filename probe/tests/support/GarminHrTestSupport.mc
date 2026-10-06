import Toybox.Sensor;
import Toybox.Lang;
class GarminHrTestApi extends GarminApi {
    var enabled = [];
    var disabled = [];
    var listeners = [];
    var available = true;
    var failEvents = false;
    var failUnregister = false;
    var failDisable = false;
    function hrEnableType(kind) {
        enabled.add(kind);
        return available;
    }
    function hrDisableType(kind) {
        disabled.add(kind);
        if (failDisable) {
            throw new Lang.Exception();
        }
        return true;
    }
    function hrEvents(listener) {
        listeners.add(listener);
        if (failUnregister && listener == null) {
            throw new Lang.Exception();
        }
        if (failEvents && listener != null) {
            throw new Lang.Exception();
        }
    }
}
class GarminHrTestReceiver {
    var value = null;
    function receive(v) {
        value = v;
    }
}

class GarminHrTestInfo {
    var heartRate = 68;
}
