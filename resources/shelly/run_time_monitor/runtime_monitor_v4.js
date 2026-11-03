// ============================================================
// Shelly Plug - Tägliche kumulierte Einschaltzeit -> Rails API
// Verbesserte Version
// ============================================================
// Misst alle INTERVAL_SECONDS die Laufzeit oberhalb von
// MinRunningWatt und akkumuliert sie lokal in der KVS.
// Das Senden an Rails erfolgt entkoppelt davon nur alle
// SEND_INTERVAL_SECONDS (spart API-Requests), sowie einmal
// sofort bei Tageswechsel, um den finalen Tageswert nicht zu
// verlieren.
// ============================================================

let SHELLY_ID = undefined;
let RAILS_API_URL = "http://192.168.0.147:3000";
let X_Api_Key = null; // KEIN Default-Key mehr - muss aus KVS kommen

let min_running_watt = 50;
const INTERVAL_SECONDS = 20;      // Mess-Intervall (lokal akkumulieren)
let SEND_INTERVAL_SECONDS = 300;  // Sende-Intervall (Default 5 Min, per KVS änderbar)
let MQTTpublish = true;
let DEBUG = true;

let device_info = Shelly.getDeviceInfo();
let parts = device_info.id.split('-');
let DEVICE_ID = parts[parts.length - 1];

let isInitialized = false;
let secondsSinceLastSend = 0;

function log(msg) {
  if (DEBUG) print(msg);
}

log('Die Geräte-ID lautet: ' + DEVICE_ID);

// ------------------------------------------------------------
// Hilfsfunktion: Datum als YYYY-MM-DD mit führenden Nullen
// ------------------------------------------------------------

function pad2(n) {
  return n < 10 ? "0" + n : "" + n;
}

function formatDate(d) {
  return d.getFullYear() + "-" + pad2(d.getMonth() + 1) + "-" + pad2(d.getDate());
}

// ------------------------------------------------------------
// Initialisierung
// ------------------------------------------------------------

function initialize() {
  let pending = 5;

  function doneOne() {
    pending--;
    if (pending === 0) finishInit();
  }

  Shelly.call("KVS.Get", { key: "MinRunningWatt" }, function (res, error_code) {
    if (error_code === 0 && res && res.value) {
      let v = parseInt(res.value, 10);
      if (!isNaN(v)) min_running_watt = v;
    }
    doneOne();
  });

  Shelly.call("KVS.Get", { key: "SendIntervalSeconds" }, function (res, error_code) {
    if (error_code === 0 && res && res.value) {
      let v = parseInt(res.value, 10);
      if (!isNaN(v) && v >= INTERVAL_SECONDS) SEND_INTERVAL_SECONDS = v;
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

  Shelly.call("KVS.Get", { key: "RailsApiUrl" }, function (res, error_code) {
    if (error_code === 0 && res && res.value) {
      RAILS_API_URL = res.value;
    } else {
      log("Hinweis: RailsApiUrl nicht in KVS, nutze Default: " + RAILS_API_URL);
    }
    doneOne();
  });

  Shelly.call("Mqtt.GetConfig", "", function (res) {
    if (res && res.topic_prefix) {
      SHELLY_ID = res.topic_prefix;
    }
    doneOne();
  });
}

function finishInit() {
  if (isInitialized) return;
  isInitialized = true;
  log("Initialisierung abgeschlossen (MinWatt=" + min_running_watt +
      ", SendInterval=" + SEND_INTERVAL_SECONDS + "s). Starte Timer.");

  Timer.set(INTERVAL_SECONDS * 1000, true, function () {
    updateDailyRunTimeAndCheck();
  });
  updateDailyRunTimeAndCheck(); // sofort beim Start einmal prüfen
}

// Skript-Start
initialize();

// ------------------------------------------------------------
// Tageswechsel-Prüfung
// ------------------------------------------------------------

function updateDailyRunTimeAndCheck() {
  let now = new Date();
  let currentDate = formatDate(now);

  Shelly.call("KVS.Get", { key: "RunTimeDate" }, function (res) {
    if (!res || res.value !== currentDate) {
      // Neuer Tag: zuerst den finalen Wert des alten Tages sichern/senden,
      // BEVOR zurückgesetzt wird - sonst geht der letzte Teil-Zeitraum
      // seit dem letzten periodischen Send verloren.
      let previousDate = (res && res.value) ? res.value : null;

      Shelly.call("KVS.Get", { key: "DailyRunTime" }, function (runRes) {
        let previousRunTime = (runRes && runRes.value) ? parseInt(runRes.value, 10) : 0;

        function resetForNewDay() {
          Shelly.call("KVS.Set", { key: "RunTimeDate", value: currentDate }, function () {
            Shelly.call("KVS.Set", { key: "DailyRunTime", value: '0' }, function () {
              secondsSinceLastSend = 0;
              continueAfterRuntimeUpdate(currentDate);
            });
          });
        }

        if (previousDate && previousRunTime > 0) {
          log("Tageswechsel erkannt. Sende finalen Wert für " + previousDate + ": " + previousRunTime);
          send2db(previousDate, previousRunTime, resetForNewDay);
        } else {
          resetForNewDay();
        }
      });
    } else {
      continueAfterRuntimeUpdate(currentDate);
    }
  });
}

// ------------------------------------------------------------
// Laufzeit messen und ggf. periodisch senden
// ------------------------------------------------------------

function continueAfterRuntimeUpdate(currentDate) {
  Shelly.call("KVS.Get", { key: "DailyRunTime" }, function (res) {
    let currentRunTime = 0;
    if (res && res.value) {
      currentRunTime = parseInt(res.value, 10);
    }

    let switchStatus = Shelly.getComponentStatus('switch:0');
    let currentPower = (switchStatus && typeof switchStatus.apower === "number")
      ? switchStatus.apower
      : null;

    if (currentPower === null) {
      log("WARNUNG: switch:0 Status nicht verfügbar, überspringe diesen Tick.");
      return;
    }

    let isRunning = currentPower > min_running_watt;

    if (isRunning) {
      currentRunTime += INTERVAL_SECONDS;
      log(currentDate + ': ' + currentRunTime + 's (min: ' + min_running_watt +
          'W | current: ' + currentPower + 'W)');

      Shelly.call("KVS.Set", { key: "DailyRunTime", value: currentRunTime.toString() });
    }

    // Sende-Intervall unabhängig vom Mess-Intervall hochzählen
    secondsSinceLastSend += INTERVAL_SECONDS;
    if (secondsSinceLastSend >= SEND_INTERVAL_SECONDS) {
      secondsSinceLastSend = 0;
      send2db(currentDate, currentRunTime);
    }

    if (typeof SHELLY_ID !== "undefined" && MQTTpublish === true) {
      let payload = {
        dailyruntime: parseFloat((currentRunTime / 3600).toFixed(2))
      };
      MQTT.publish(SHELLY_ID + "/metrics", JSON.stringify(payload), 0, false);
    }
  });
}

// ------------------------------------------------------------
// Rails API
// ------------------------------------------------------------

function send2db(currentDate, currentRunTime, callback) {
  let apiuri = RAILS_API_URL + '/api/v1/daily_runtime';
  let headers = { 'Content-Type': 'application/json' };
  if (X_Api_Key) headers['X-Api-Key'] = X_Api_Key;

  let body = JSON.stringify({
    device_id: DEVICE_ID,
    day: currentDate,
    runtime: currentRunTime
  });

  log("Sende Runtime an Rails API: " + apiuri + " (" + currentDate + ": " + currentRunTime + "s)");

  Shelly.call("HTTP.Request", {
    url: apiuri,
    method: "POST",
    headers: headers,
    body: body,
    timeout: 10
  }, function (result, error_code, error_message) {
    if (error_code !== 0) {
      log("Fehler beim Senden des Requests: " + error_message);
    } else if (result && result.code >= 200 && result.code < 300) {
      log("Rails API OK (" + result.code + ")");
    } else {
      log("Rails API antwortete mit unerwartetem Code: " + (result ? result.code : "unknown"));
    }
    if (callback) callback();
  });
}
