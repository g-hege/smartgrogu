// ============================================================
// Shelly Input Monitoring (Lichtschalter) -> Rails API
// ============================================================

// --- Konfiguration (Defaults, werden aus KVS überschrieben) ---
let DEVICE_NAME = "Shelly Switch"; // Fallback, falls KVS-Key "DeviceName" fehlt
let RAILS_API_URL = "http://192.168.0.147:3000";
let X_Api_Key = null; // KEIN Default-Key mehr - muss aus KVS kommen
let DEBUG = true;

let device_info = Shelly.getDeviceInfo();
let parts = device_info.id.split('-');
let DEVICE_ID = parts[parts.length - 1];

let lastInputState = null; // null = noch unbekannt, verhindert Fehl-Events beim Start
let isInitialized = false;

function log(msg) {
  if (DEBUG) print(msg);
}

// ------------------------------------------------------------
// Event-Handler sofort registrieren, Events puffern bis KVS geladen ist
// ------------------------------------------------------------

let bufferedEvents = [];
Shelly.addEventHandler(function (event) {
  if (!isInitialized) {
    bufferedEvents.push(event);
    return;
  }
  processEvent(event);
});

// ------------------------------------------------------------
// Initialisierung
// ------------------------------------------------------------

function initialize() {
  let pending = 3;

  function doneOne() {
    pending--;
    if (pending === 0) finishInit();
  }

  Shelly.call("KVS.Get", { key: "DeviceName" }, function (res, error_code, error_message) {
    if (error_code === 0 && res && res.value) {
      DEVICE_NAME = res.value;
    } else {
      log("Hinweis: DeviceName nicht in KVS, nutze Default: " + DEVICE_NAME);
    }
    doneOne();
  });

  Shelly.call("KVS.Get", { key: "X-Api-Key" }, function (res, error_code, error_message) {
    if (error_code === 0 && res && res.value) {
      X_Api_Key = res.value;
    } else {
      log("WARNUNG: X-Api-Key nicht aus KVS geladen (" + error_message + "). Sende OHNE Key.");
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
}

function finishInit() {
  if (isInitialized) return;

  // Aktuellen Zustand einlesen, um Fehl-Events beim Start zu vermeiden
  let initialInput = Shelly.getComponentStatus("input:0");
  if (initialInput && typeof initialInput.state !== "undefined") {
    lastInputState = initialInput.state;
  }
  log("Initialer Input-Status: " + lastInputState);

  isInitialized = true;
  log("KVS geladen. Überwachung für " + DEVICE_NAME + " gestartet.");

  // Gepufferte Events nachträglich verarbeiten
  for (let i = 0; i < bufferedEvents.length; i++) {
    processEvent(bufferedEvents[i]);
  }
  bufferedEvents = [];
}

// ------------------------------------------------------------
// Event-Verarbeitung
// ------------------------------------------------------------

function processEvent(event) {
  if (event.component !== "input:0" || typeof event.info.state === "undefined") return;

  let currentState = event.info.state;

  if (currentState === true && lastInputState !== true) {
    lastInputState = true;
    log(DEVICE_NAME + " wurde EINGESCHALTET!");
    sendToRailsApi("ON");
  } else if (currentState === false && lastInputState !== false) {
    lastInputState = false;
    log(DEVICE_NAME + " wurde AUSGESCHALTET.");
    sendToRailsApi("OFF");
  }
}

// ------------------------------------------------------------
// Rails API (mit einmaligem Retry)
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

  log((isRetry ? "Retry: " : "") + "Sende Event '" + eventState + "' an Rails API: " + apiuri);

  Shelly.call("HTTP.Request", {
    url: apiuri,
    method: "POST",
    headers: headers,
    body: body,
    timeout: 10
  }, function (result, error_code, error_message) {
    if (error_code !== 0) {
      log("Fehler beim Senden an Rails API: " + error_message);
      if (!isRetry) {
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
