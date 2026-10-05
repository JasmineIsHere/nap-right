import Toybox.Lang;

// Monkey C requires invoked method names to exist somewhere at compile time.
// This red-only, never-instantiated type declares names without supplying a probe.
// Normal builds exclude it; its constructor and every method fail if ever reached.
class ProbeSignatureMarkers {
    function initialize() {
        throw new Lang.Exception();
    }
    function start(elapsedMs, wallSeconds) {
        throw new Lang.Exception();
    }
    function heartRate(elapsedMs, wallSeconds, bpm) {
        throw new Lang.Exception();
    }
    function accelerometer(elapsedMs, wallSeconds, payload) {
        throw new Lang.Exception();
    }
    function rr(elapsedMs, wallSeconds, intervals) {
        throw new Lang.Exception();
    }
    function tick(elapsedMs, wallSeconds) {
        throw new Lang.Exception();
    }
    function stop(elapsedMs, wallSeconds, reason) {
        throw new Lang.Exception();
    }
    function snapshot() {
        throw new Lang.Exception();
    }
    function drain() {
        throw new Lang.Exception();
    }
}
