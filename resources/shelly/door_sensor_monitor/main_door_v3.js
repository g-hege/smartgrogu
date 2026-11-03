// ============================================================
// Shelly BLE Door Sensor (BTHome) -> Rails API + Signal
// Verbesserte Version
// ============================================================

const DEVICE_NAME = "Main_Door";
const SENSOR_MAC = "fc:4d:6a:38:91:fd"; // MAC-Adresse des Türsensors
const LOW_BATTERY_THRESHOLD = 20;       // % - unterhalb dessen extra gemeldet wird

// --- Konfiguration (Defaults, werden aus KVS überschrieben) ---
let RAILS_API_URL = "http://192.168.0.147:3000";
let X_Api_Key = null;          // KEIN Default-Key mehr - muss aus KVS kommen
let SIGNAL_URL_BASE = null;    // z.B. "https://signal.callmebot.com/signal/send.php"
let SIGNAL_PHONE = null;       // Phone/UUID-Parameter für CallMeBot
let SIGNAL_API_KEY = null;     // API-Key-Parameter für CallMeBot
let DEBUG = true;

let device_info = Shelly.getDeviceInfo();
let parts = device_info.id.split('-');
let DEVICE_ID = parts[parts.length - 1];

let lastState = 0;     // 0=closed, 1=open
let lastPacketId = -1; // dedupe
let isInitialized = false;
let lastReportedBattery = null;

function log(msg) {
  if (DEBUG) print(msg);
}

// ------------------------------------------------------------
// Initialisierung
// ------------------------------------------------------------

function initialize() {
  let pending = 5;

  function doneOne() {
    pending--;
    if (pending === 0) {
      isInitialized = true;
      log("KVS geladen. Starte BLE-Scanner...");
      startBleScanner();
    }
  }

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

  Shelly.call("KVS.Get", { key: "SignalUrlBase" }, function (res, error_code, error_message) {
    if (error_code === 0 && res && res.value) {
      SIGNAL_URL_BASE = res.value;
    } else {
      log("WARNUNG: SignalUrlBase nicht in KVS. Signal-Benachrichtigung deaktiviert.");
    }
    doneOne();
  });

  Shelly.call("KVS.Get", { key: "SignalPhone" }, function (res, error_code, error_message) {
    if (error_code === 0 && res && res.value) {
      SIGNAL_PHONE = res.value;
    }
    doneOne();
  });

  Shelly.call("KVS.Get", { key: "SignalApiKey" }, function (res, error_code, error_message) {
    if (error_code === 0 && res && res.value) {
      SIGNAL_API_KEY = res.value;
    }
    doneOne();
  });
}

// ------------------------------------------------------------
// Rails API (mit einmaligem Retry, wie beim Presence-Script)
// ------------------------------------------------------------

function sendToRailsApi(eventState, isoTimestamp, batteryPct, isRetry) {
  let apiuri = RAILS_API_URL + '/api/v1/event_monitor';
  let headers = { 'Content-Type': 'application/json' };
  if (X_Api_Key) headers['X-Api-Key'] = X_Api_Key;

  let infoText = DEVICE_NAME + " " + eventState;
  if (typeof batteryPct === "number") infoText += " (Battery " + batteryPct + "%)";

  let payload = {
    device_id: SENSOR_MAC,
    event_stamp: isoTimestamp,
    event: eventState,
    info: infoText
  };
  if (typeof batteryPct === "number") payload.battery = batteryPct;

  let body = JSON.stringify(payload);

  log((isRetry ? "Retry: " : "") + "Sende an Rails API: " + apiuri + " (" + eventState + ")");

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
          sendToRailsApi(eventState, isoTimestamp, batteryPct, true);
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
// Signal-Benachrichtigung (optional, nur wenn KVS konfiguriert)
// ------------------------------------------------------------

function sendSignalMessage(eventState, timeStr) {
  if (!SIGNAL_URL_BASE || !SIGNAL_PHONE || !SIGNAL_API_KEY) {
    log("Signal nicht konfiguriert (KVS unvollständig) - überspringe Benachrichtigung.");
    return;
  }

  let message = "%20" + DEVICE_NAME + "%20" + eventState + timeStr;
  let encodedUrl = SIGNAL_URL_BASE
    + "?phone=" + SIGNAL_PHONE
    + "&apikey=" + SIGNAL_API_KEY
    + "&text=" + message;

  Shelly.call("HTTP.GET", { url: encodedUrl, timeout: 30 }, function (res, err) {
    if (err || (res && res.code !== 200)) {
      log("ERROR Signal Send -> Code: " + (res ? res.code : "unknown"));
    } else {
      log("Signal Nachricht erfolgreich gesendet. Status: " + res.code);
    }
  });
}

function buildTimeStr(sysStatus) {
  if (!sysStatus || !sysStatus.time) return "";
  let dateStr = sysStatus.date;
  if (!dateStr && sysStatus.unixtime) {
    let d = new Date(sysStatus.unixtime * 1000);
    let day = d.getDate();
    let month = d.getMonth() + 1;
    let year = d.getFullYear();
    if (day < 10) day = "0" + day;
    if (month < 10) month = "0" + month;
    dateStr = day + "." + month + "." + year;
  }
  return dateStr ? ("%20" + dateStr + "%20" + sysStatus.time) : "";
}

function getIsoTimestamp(sysStatus) {
  if (sysStatus && sysStatus.unixtime) {
    return new Date(sysStatus.unixtime * 1000).toISOString();
  }
  return new Date().toISOString();
}

// ------------------------------------------------------------
// BLE-Scanner + BTHome-Parsing
// ------------------------------------------------------------

function startBleScanner() {
  log(DEVICE_NAME + " SENSOR SCRIPT STARTED");
  BLE.Scanner.Start({ active: true, duration_ms: BLE.Scanner.INFINITE_SCAN });

  BLE.Scanner.Subscribe(function (event, result) {
    if (event !== BLE.Scanner.SCAN_RESULT) return;
    if (!result.service_data || !result.service_data.fcd2) return;
    if (result.addr !== SENSOR_MAC) return;

    let payload = result.service_data.fcd2;
    if (payload.length < 3) return; // zu kurz, um gültig zu sein

    if (lastPacketId === payload.at(2)) return; // Duplikat überspringen
    lastPacketId = payload.at(2);

    // ——— BTHOME PARSEN (mit Bounds-Checks) ———
    let i = 1;
    let battery = null;
    let contact = null;

    while (i < payload.length) {
      let obj_id = payload.at(i);
      i++;
      if (obj_id === 0x00) {
        // Packet ID (1 Byte) - wird bereits separat über payload.at(2) für
        // die Dedupe-Prüfung verwendet, hier nur überspringen.
        if (i >= payload.length) break;
        i++;
      } else if (obj_id === 0x01) {
        if (i >= payload.length) break; // unvollständiges Objekt
        battery = payload.at(i);
        i++;
      } else if (obj_id === 0x2D) {
        if (i >= payload.length) break;
        contact = payload.at(i);
        i++;
      } else {
        // Unbekannte/nicht behandelte Objekt-ID: sicherheitshalber abbrechen,
        // statt evtl. falsch weiterzuspringen (Objektlängen variieren pro Typ).
        log("Unbekannte BTHome Objekt-ID 0x" + obj_id.toString(16) + " - Parsing gestoppt.");
        break;
      }
    }

    if (battery !== null && battery !== lastReportedBattery) {
      lastReportedBattery = battery;
      if (battery <= LOW_BATTERY_THRESHOLD) {
        log("WARNUNG: Niedriger Batteriestand (" + battery + "%) bei " + DEVICE_NAME);
      }
    }

    if (contact === null) return; // kein auswertbares Contact-Feld in diesem Paket

    let sysStatus = Shelly.getComponentStatus("sys");
    let isoTimestamp = getIsoTimestamp(sysStatus);

    if (contact === 1 && lastState !== 1) {
      lastState = 1;
      log("Door Sensor Opened!");

      sendSignalMessage("Opened", buildTimeStr(sysStatus));
      sendToRailsApi("Open", isoTimestamp, battery);

    } else if (contact === 0 && lastState !== 0) {
      lastState = 0;
      log("Door " + DEVICE_NAME + " Sensor Closed.");

      // Signal-Benachrichtigung bewusst nur bei "Open" - kein Spam bei Closed
      sendToRailsApi("Closed", isoTimestamp, battery);
    }
  });
}

// Skript-Start
initialize();
