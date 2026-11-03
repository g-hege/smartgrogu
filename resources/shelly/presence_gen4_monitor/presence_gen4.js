// Konfiguration
const DEVICE_NAME = "Shelly Presence Gen4";
const INACTIVITY_TIMEOUT_MS = 10000; // 10 Sekunden Nachlauf nach letztem Track-Event

let RAILS_API_URL = "http://192.168.0.147:3000";
let X_Api_Key = "12345";

let device_info = Shelly.getDeviceInfo();
let parts = device_info.id.split('-');
let DEVICE_ID = parts[parts.length - 1];

let lastPresenceState = false;
let isInitialized = false;
let resetTimer = null;

function initialize() {
  let keyLoaded = false;
  let apiurlLoaded = false;

  Shelly.call("KVS.Get", { key: "X-Api-Key" }, function(res) {
    if (res && res.value) { X_Api_Key = res.value; }
    keyLoaded = true;
    checkIfReady();
  });

  Shelly.call("KVS.Get", { key: "RailsApiUrl" }, function(res) {
    if (res && res.value) { RAILS_API_URL = res.value; }
    apiurlLoaded = true;
    checkIfReady();
  });

  function checkIfReady() {
    if (keyLoaded && apiurlLoaded && !isInitialized) {
      isInitialized = true;
      print("KVS geladen. Initialisiere Sensor-Status...");
      
      // Initialen Status auslesen, um Start-Fehlauslösung zu vermeiden
      syncInitialState(function() {
        print("Gen4 Überwachung bereit. Höre auf neue Events...");
        startMonitoring();
      });
    }
  }
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
  print("Initialer Präsenz-Status: " + lastPresenceState);
  if (callback) callback();
}

function sendToRailsApi(eventState) {
  let sysStatus = Shelly.getComponentStatus("sys");
  let isoTimestamp = new Date().toISOString();

  if (sysStatus && sysStatus.unixtime) {
    let d = new Date(sysStatus.unixtime * 1000);
    isoTimestamp = d.toISOString();
  }

  let apiuri = RAILS_API_URL + '/api/v1/event_monitor';
  let headers = {
    'Content-Type': 'application/json',
    'X-Api-Key': X_Api_Key
  };

  let body = JSON.stringify({
    "device_id": DEVICE_ID,
    "event_stamp": isoTimestamp,
    "event": eventState,
    "info": DEVICE_NAME + " " + eventState
  });

  print("Sende Gen4 Event an Rails API: " + apiuri);
  Shelly.call("HTTP.Request", {
    url: apiuri,
    method: "POST",
    headers: headers,
    body: body,
    timeout: 10
  }, function(result, error_code, error_message) {
    if (error_code !== 0) {
      print("Fehler beim Senden: " + error_message);
    } else {
      print("Rails API Response Code: " + (result ? result.code : "unknown"));
    }
  });
}

function startMonitoring() {
  Shelly.addEventHandler(function(event) {
    if (event.component === "presence" && event.info) {
      
      // Gen4 Track Event verarbeiten
      if (event.info.event === "track" && Array.isArray(event.info.object)) {
        let hasObjects = event.info.object.length > 0;
        handlePresenceEvent(hasObjects);
      }
      // Standard Presence Flag
      else if (typeof event.info.presence !== "undefined") {
        handlePresenceEvent(event.info.presence);
      }
    }
  });
}

function handlePresenceEvent(isPresent) {
  if (isPresent) {
    // Reset-Timer erneuern / stoppen, solange Bewegung/Person registriert wird
    if (resetTimer !== null) {
      Timer.clear(resetTimer);
      resetTimer = null;
    }

    // Nur senden, wenn es sich um einen echtem Wechsel von false -> true handelt
    if (!lastPresenceState) {
      lastPresenceState = true;
      print(">>> ECHTE GEN4 PRÄSENZ / PERSON ERKANNT <<<");
      sendToRailsApi("Motion");
    }

    // Timer starten: Setzt Status nach 10s Inaktivität zurück
    resetTimer = Timer.set(INACTIVITY_TIMEOUT_MS, false, function() {
      lastPresenceState = false;
      resetTimer = null;
      print("Präsenz beendet. Bereit für die nächste Erkennung.");
    });
  }
}

initialize();