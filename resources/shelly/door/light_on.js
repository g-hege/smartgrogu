// Konfiguration
const DEVICE_NAME = "WC Light";

// Default-Werte für KVS Fallback
let RAILS_API_URL = "http://192.168.0.147:3000";
let X_Api_Key = "12345";

// Gerätekennung ermitteln
let device_info = Shelly.getDeviceInfo();
let parts = device_info.id.split('-');
let DEVICE_ID = parts[parts.length - 1];

let lastInputState = false;
let isInitialized = false;

// KVS Initialisierung
function initialize() {
  let keyLoaded = false;
  let apiurlLoaded = false;

  Shelly.call("KVS.Get", { key: "X-Api-Key" }, function(res) {
    if (res && res.value) {
      X_Api_Key = res.value;
    }
    keyLoaded = true;
    checkIfReady();
  });

  Shelly.call("KVS.Get", { key: "RailsApiUrl" }, function(res) {
    if (res && res.value) {
      RAILS_API_URL = res.value;
    }
    apiurlLoaded = true;
    checkIfReady();
  });

  function checkIfReady() {
    if (keyLoaded && apiurlLoaded && !isInitialized) {
      isInitialized = true;
      print("KVS geladen. Überwachung für " + DEVICE_NAME + " gestartet.");
      startInputMonitor();
    }
  }
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

  print("Sende Event '" + eventState + "' an Rails API: " + apiuri);
  Shelly.call("HTTP.Request", {
    url: apiuri,
    method: "POST",
    headers: headers,
    body: body,
    timeout: 10
  }, function(result, error_code, error_message) {
    if (error_code !== 0) {
      print("Fehler beim Senden an Rails API: " + error_message);
    } else {
      print("Rails API Response Code: " + (result ? result.code : "unknown"));
    }
  });
}

function startInputMonitor() {
  // Status beim Start prüfen
  let initialInput = Shelly.getComponentStatus("input:0");
  if (initialInput) {
    lastInputState = initialInput.state;
  }

  // Input Event Handler registrieren
  Shelly.addEventHandler(function(event) {
    // Überprüfen, ob das Event vom Eingang (input:0) stammt
    if (event.component === "input:0" && typeof event.info.state !== "undefined") {
      let currentState = event.info.state;

      // Nur reagieren, wenn der Zustand von OFF auf ON wechselt (Licht eingeschaltet)
      if (currentState === true && lastInputState !== true) {
        lastInputState = true;
        print(DEVICE_NAME + " wurde EINGESCHALTET!");
        sendToRailsApi("ON");
      } 
      // Zustand aktualisieren, wenn das Licht wieder ausgeschaltet wird
      else if (currentState === false) {
        lastInputState = false;
        print(DEVICE_NAME + " wurde AUSGESCHALTET.");
      }
    }
  });
}

// Skript-Start
initialize();