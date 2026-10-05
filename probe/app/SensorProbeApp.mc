import Toybox.Application;
import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.System;
class SensorProbeApp extends Application.AppBase {
    var controller;
    function initialize() {
        AppBase.initialize();
        controller = (new WatchFactory()).create(new GarminApi());
    }
    function getInitialView() {
        var view = new ProbeView(controller);
        return [view, new ProbeDelegate(view)];
    }
    function onInactive(state) {
        controller.stop("interrupted");
    }
    function onStop(state) {
        controller.stop("interrupted");
    }
}
class ProbeView extends WatchUi.View {
    var controller;
    var durations = [2, 20, 45, 66];
    var selection = 0;
    var details = false;
    var message = "";
    function initialize(c) {
        View.initialize();
        controller = c;
    }
    function toggle() {
        if (controller.state()["running"]) {
            controller.stop("cancelled");
            message = "Stopped";
        } else {
            message = controller.start(durations[selection]) ? "" : "Unable to start";
        }
        WatchUi.requestUpdate();
    }
    function next() {
        if (!controller.state()["running"]) {
            selection = (selection + 1) % 4;
        } else {
            details = !details;
        }
        WatchUi.requestUpdate();
    }
    function exportLast() {
        message = controller.exportLast()
            ? "Report printed; USB check needed"
            : "No export available";
        WatchUi.requestUpdate();
    }
    function text(dc, y, value, font) {
        dc.drawText(dc.getWidth() / 2, y, font, value, Graphics.TEXT_JUSTIFY_CENTER);
    }
    function value(v) {
        return v == null ? "unavailable" : v.toString();
    }
    function durationText(ms) {
        var secs = ms / 1000;
        return (secs / 60).format("%d") + ":" + (secs % 60).format("%02d");
    }
    function onUpdate(dc) {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();
        if (System.getDisplayMode() != System.DISPLAY_MODE_HIGH_POWER) {
            return;
        }
        var s = controller.state();
        var small = Graphics.FONT_XTINY;
        var normal = Graphics.FONT_SMALL;
        text(dc, 32, "SensorProbe", normal);
        if (!s["running"]) {
            text(dc, 86, durations[selection] + " minute test", normal);
            text(dc, 128, "Select / tap: Start", small);
            text(dc, 158, "Swipe / down: Duration", small);
            text(dc, 188, "Hold menu: Export last", small);
            text(dc, 220, s["alarm"] != null ? "Alarm requested; session ended" : message, small);
            if (s["recovered"]) {
                text(dc, 252, "Saved report available", small);
            }
            if (s["errors"].size() > 0) {
                text(dc, 282, s["errors"][s["errors"].size() - 1], small);
            }
        } else if (!details) {
            var remaining = durations[selection] * 60000 - s["elapsed"];
            if (remaining < 0) {
                remaining = 0;
            }
            text(dc, 72, durationText(s["elapsed"]) + " / left " + durationText(remaining), normal);
            text(dc, 118, "HR " + value(s["hr"]) + " bpm", small);
            var a = s["accel"];
            text(
                dc,
                152,
                "XYZ " + (a == null ? "unavailable" : a[0] + " " + a[1] + " " + a[2]),
                small
            );
            text(dc, 184, "RR " + value(s["rr"]) + " ms", small);
            var rm = s["rmssd"];
            text(
                dc,
                216,
                "RMSSD " + (rm == null ? "unavailable" : rm.format("%.1f")) + " ms",
                small
            );
            text(
                dc,
                250,
                s["rrEnabled"] ? "RR source unverified" : "RR registration unavailable",
                small
            );
            text(dc, 282, "Select / tap: Stop", small);
            text(dc, 310, "Swipe / down: Details", small);
        } else {
            var t = s["stats"];
            text(dc, 78, "Samples HR / XYZ / RR", small);
            text(
                dc,
                106,
                t["hrSamples"] + " / " + t["accelSamples"] + " / " + t["rrSamples"],
                small
            );
            text(
                dc,
                142,
                "Missing " + (t["hrMissing"] + t["accelMissing"] + t["rrMissingCallbacks"]),
                small
            );
            text(
                dc,
                174,
                "Rejected " + (t["hrRejected"] + t["accelRejected"] + t["rrRejected"]),
                small
            );
            text(dc, 206, "RR gaps " + t["rrGaps"] + " / drops " + t["droppedRecords"], small);
            text(dc, 238, "Battery " + s["metrics"]["battery"] / 10 + "%", small);
            text(dc, 270, "Free memory " + s["metrics"]["free"], small);
            text(
                dc,
                302,
                s["storageOk"] ? "Report writes unverified" : "Storage write error",
                small
            );
        }
    }
}
class ProbeDelegate extends WatchUi.BehaviorDelegate {
    var view;
    function initialize(v) {
        BehaviorDelegate.initialize();
        view = v;
    }
    function onSelect() {
        view.toggle();
        return true;
    }
    function onTap(event) {
        view.toggle();
        return true;
    }
    function onNextPage() {
        view.next();
        return true;
    }
    function onPreviousPage() {
        view.next();
        return true;
    }
    function onSwipe(event) {
        view.next();
        return true;
    }
    function onMenu() {
        if (!view.controller.state()["running"]) {
            view.exportLast();
        }
        return true;
    }
    function onBack() {
        if (view.controller.state()["running"]) {
            view.controller.stop("cancelled");
            WatchUi.requestUpdate();
            return true;
        }
        return false;
    }
}
