import Toybox.Application;
import Toybox.WatchUi;

// Simulator-only test entry point. This application never registers real sensors.
class ProbeTestApp extends Application.AppBase {
    function initialize() {
        AppBase.initialize();
    }

    function getInitialView() {
        return [new WatchUi.View()];
    }
}
