// ============================================================
// Shelly Presence Gen4 -> Rails API
// ============================================================

// --- Konfiguration (Defaults, werden ggf. aus KVS überschrieben) ---
const DEVICE_NAME = "Shelly Presence Gen4";
let INACTIVITY_TIMEOUT_MS = 10000; // 10s Nachlauf nach letztem Track-Event
let DEBUG = true;                  // per KVS "Debug" = "0"/"1" umschaltbar
let RAILS_API_URL = "http://192.168.0.147:3000";
let X_Api_Key = null;      

let device_info = Shelly.getDeviceInfo();
let parts = device_info.id.split('-');
let DEVICE_ID = parts[parts.length - 1];

let lastPresenceState = false;
let isInitialized = false;
let resetTimer = null;

function log(msg) {
  if (DEBUG) print(msg);
}

// ------------------------------------------------------------
// Initialisierung
// ------------------------------------------------------------

// Event-Handler SOFORT registrieren, damit während des KVS-Ladens
// nichts verloren geht -> Events werden intern gepuffert.
let bufferedEvents = [];
Shelly.addEventHandler(function (event) {
  if (!isInitialized) {
    bufferedEvents.push(event);
    return;
  }
  processEvent(event);
});

function initialize() {
  let pending = 3; // Key, Url, Debug

  function doneOne() {
    pending--;
    if (pending === 0) finishInit();
  }

  Shelly.call("KVS.Get", { key: "X-Api-Key" }, function (res, error_code, error_message) {
    if (error_code === 0 && res && res.value) {
      X_Api_Key = res.value;
    } else {
      log("WARNUNG: X-Api-Key konnte nicht aus KVS geladen werden (" + error_message + "). Sende OHNE Key.");
    }
    doneOne();
  });

  Shelly.call("KVS.Get", { key: "RailsApiUrl" }, function (res, error_code, error_message) {
    if (error_code === 0 && res && res.value) {
      RAILS_API_URL = res.value;
    } else {
      log("Hinweis: RailsApiUrl nicht in KVS, nutze Default: " + RAILS_API_URL);
    }
    doneOne();
  });

  Shelly.call("KVS.Get", { key: "InactivityTimeoutMs" }, function (res, error_code, error_message) {
    if (error_code === 0 && res && res.value) {
      let v = parseInt(res.value, 10);
      if (!isNaN(v) && v > 0) INACTIVITY_TIMEOUT_MS = v;
    }
    doneOne();
  });
}

function finishInit() {
  if (isInitialized) return;
  isInitialized = true;

  log("KVS geladen. Initialisiere Sensor-Status...");
  syncInitialState(function () {
    log("Gen4 Überwachung bereit (Timeout=" + INACTIVITY_TIMEOUT_MS + "ms). Verarbeite gepufferte Events...");
    // Gepufferte Events nachträglich verarbeiten
    for (let i = 0; i < bufferedEvents.length; i++) {
      processEvent(bufferedEvents[i]);
    }
    bufferedEvents = [];
  });
}

function syncInitialState(callback) {
  let status = Shelly.getComponentStatus("presence");
  if (status) {
    if (typeof status.presence !== "undefined") {
      lastPresenceState = status.presence;
    } else if (Array.isArray(status.object)) {
      lastPresenceState = status.object.length > 0;
    }
  }
  log("Initialer Präsenz-Status: " + lastPresenceState);
  if (callback) callback();
}

// ------------------------------------------------------------
// Event-Verarbeitung
// ------------------------------------------------------------

function processEvent(event) {
  if (event.component === "presence" && event.info) {
    if (event.info.event === "track" && Array.isArray(event.info.object)) {
      handlePresenceEvent(event.info.object.length > 0);
    } else if (typeof event.info.presence !== "undefined") {
      handlePresenceEvent(event.info.presence);
    }
  }
}

function handlePresenceEvent(isPresent) {
  if (isPresent) {
    if (resetTimer !== null) {
      Timer.clear(resetTimer);
      resetTimer = null;
    }

    if (!lastPresenceState) {
      lastPresenceState = true;
      log(">>> ECHTE GEN4 PRÄSENZ / PERSON ERKANNT <<<");
      sendToRailsApi("Motion");
    }

    resetTimer = Timer.set(INACTIVITY_TIMEOUT_MS, false, function () {
      resetTimer = null;
      if (lastPresenceState) {
        lastPresenceState = false;
        log("Präsenz beendet. Sende NoMotion.");
        sendToRailsApi("NoMotion");
      }
    });
  }
}

// ------------------------------------------------------------
// API-Kommunikation (mit einmaligem Retry)
// ------------------------------------------------------------

function sendToRailsApi(eventState, isRetry) {
  let sysStatus = Shelly.getComponentStatus("sys");
  let isoTimestamp = new Date().toISOString();

  if (sysStatus && sysStatus.unixtime) {
    isoTimestamp = new Date(sysStatus.unixtime * 1000).toISOString();
  }

  let apiuri = RAILS_API_URL + '/api/v1/event_monitor';
  let headers = { 'Content-Type': 'application/json' };
  if (X_Api_Key) headers['X-Api-Key'] = X_Api_Key;

  let body = JSON.stringify({
    device_id: DEVICE_ID,
    event_stamp: isoTimestamp,
    event: eventState,
    info: DEVICE_NAME + " " + eventState
  });

  log((isRetry ? "Retry: " : "") + "Sende Gen4 Event an Rails API: " + apiuri + " (" + eventState + ")");

  Shelly.call("HTTP.Request", {
    url: apiuri,
    method: "POST",
    headers: headers,
    body: body,
    timeout: 10
  }, function (result, error_code, error_message) {
    if (error_code !== 0) {
      log("Fehler beim Senden (" + eventState + "): " + error_message);
      if (!isRetry) {
        // Ein einmaliger Retry nach 5s, z.B. bei kurzem WLAN-Aussetzer
        Timer.set(5000, false, function () {
          sendToRailsApi(eventState, true);
        });
      } else {
        log("Retry ebenfalls fehlgeschlagen. Event " + eventState + " verworfen.");
      }
    } else if (result && result.code >= 200 && result.code < 300) {
      log("Rails API OK (" + result.code + ")");
    } else {
      log("Rails API antwortete mit unerwartetem Code: " + (result ? result.code : "unknown"));
    }
  });
}

// ------------------------------------------------------------
initialize();