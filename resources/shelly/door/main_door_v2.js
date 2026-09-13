const DEVICE_NAME = 'Maindoor'
const SENSOR_MAC = "fc:4d:6a:38:91:fd"; // MAC-Adresse des Türsensors
const SIGNAL_URL = "https://signal.callmebot.com/signal/send.php?phone=555db374-365a-4115-ba4e-f75d3c28cb23&apikey=948035&text=";

// Default-Werte für KVS Fallback
let RAILS_API_URL = "http://192.168.0.147:3000";
let X_Api_Key = "12345";

// Gerätekennung aus Shelly Info ermitteln
let device_info = Shelly.getDeviceInfo();
let parts = device_info.id.split('-');
let DEVICE_ID = parts[parts.length - 1];

let lastState = 0;   // 0=closed, 1=open
let lastPacketId = -1; // dedupe
let isInitialized = false;

// KVS Initialisierung (analog zu runtime_monitoring)
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
      print("KVS geladen. Starte BLE-Scanner...");
      startBleScanner();
    }
  }
}

function sendToRailsApi(isoTimestamp) {
  let apiuri = RAILS_API_URL + '/api/v1/event_monitor';
  let headers = {
    'Content-Type': 'application/json',
    'X-Api-Key': X_Api_Key
  };
  let body = JSON.stringify({
    "device_id": SENSOR_MAC,
    "event_stamp": isoTimestamp,
    "event": "Open",
    "info": DEVICE_NAME + ' Opened'
  });

  print("Sende an Rails API: " + apiuri);
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

function startBleScanner() {
  print(DEVICE_NAME + " DOOR SENSOR SCRIPT STARTED");
  BLE.Scanner.Start({ active: true, duration_ms: BLE.Scanner.INFINITE_SCAN });

  BLE.Scanner.Subscribe(function(event, result) {
    if (event !== BLE.Scanner.SCAN_RESULT) return;
    if (!result.service_data || !result.service_data.fcd2) return;
    if (result.addr !== SENSOR_MAC) return;

    let payload = result.service_data.fcd2;
    if (lastPacketId === payload.at(2)) return; // skip duplicates
    lastPacketId = payload.at(2);

    // ——— PARSE BTHOME ———
    let i = 1;
    let battery = 0, contact = 0;

    while (i < payload.length) {
      let obj_id = payload.at(i++);
      if (obj_id === 0x01) { battery = payload.at(i); i++; }
      else if (obj_id === 0x2D) { contact = payload.at(i); i++; }
      else { i++; }
    }

    if (contact === 1 && lastState !== 1) {
      lastState = 1;
      print("Door Sensor Opened!");

      let sysStatus = Shelly.getComponentStatus("sys");
      let timeStr = "";
      let isoTimestamp = new Date().toISOString(); // Default-Fall

      if (sysStatus && sysStatus.unixtime) {
        // Erzeuge ISO-String für Rails (z.B. "2026-09-13T10:00:00.000Z")
        let d = new Date(sysStatus.unixtime * 1000);
        isoTimestamp = d.toISOString();
      }

      if (sysStatus && sysStatus.time) {
        let time = sysStatus.time;
        let dateStr = "";

        if (sysStatus.date) {
          dateStr = sysStatus.date;
        } else if (sysStatus.unixtime) {
          let d = new Date(sysStatus.unixtime * 1000);
          let day = d.getDate();
          let month = d.getMonth() + 1;
          let year = d.getFullYear();

          if (day < 10) day = "0" + day;
          if (month < 10) month = "0" + month;

          dateStr = day + "." + month + "." + year;
        }

        timeStr = "%20" + dateStr + "%20" + time;
      }

      // 1. Signal Nachricht senden
      let message = "%20" + DEVICE_NAME + "%20Opened" + timeStr;
      let encodedUrl = SIGNAL_URL + message;

      Shelly.call("HTTP.GET", {
        url: encodedUrl,
        timeout: 30
      }, function(res, err) {
        if (err) {
          print("ERROR → " + err + " (Code: " + (res ? res.code : "unknown") + ")");
        } else {
          print("Signal Nachricht erfolgreich gesendet. Status: " + res.code);
        }
      });

      // 2. An Rails API (event_monitor) senden
      sendToRailsApi(isoTimestamp);

    } else if (contact === 0) {
      lastState = 0;
      print("Door " + DEVICE_NAME  + "Sensor Closed.");
    }
  });
}

// Skript-Start
initialize();