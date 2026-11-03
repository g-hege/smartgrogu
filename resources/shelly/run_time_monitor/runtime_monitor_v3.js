// Dieser Skript misst die täglich, kumulierte Einschaltzeit eines Shelly-Plugs pro Tag
// und sendet die Daten an eine Ruby-on-Rails-App

let SHELLY_ID = undefined;  
let RAILS_API_URL = "http://192.168.0.147:3000"; 
let X_Api_Key = '12345'

let min_running_watt = 50; 
let INTERVAL_SECONDS = 20; // check every 20 seconds
let MQTTpublish = true;
let log = 1;

let device_info = Shelly.getDeviceInfo();
let parts = device_info.id.split('-');
let DEVICE_ID = parts[parts.length - 1];

console.log('Die Geräte-ID lautet: ' + DEVICE_ID);

let isInitialized = false;

function initialize() {
    let wattLoaded = false;
    let keyLoaded = false;
    let apiurlLoaded = false;
    let mqttLoaded = false;

    // Lade die min_running_watt
    Shelly.call("KVS.Get", { key: "MinRunningWatt" }, function(res) {
        if (res && res.value) {
            min_running_watt = parseInt(res.value, 10);
        }
        wattLoaded = true;
        checkIfReady();
    });

    // Lade den X_Api_Key
    Shelly.call("KVS.Get", { key: "X-Api-Key" }, function(res) {
        if (res && res.value) {
            X_Api_Key = res.value;
        }
        keyLoaded = true;
        checkIfReady();
    });

    // Lade RailsApiUrl
    Shelly.call("KVS.Get", { key: "RailsApiUrl" }, function(res) {
        if (res && res.value) {
            RAILS_API_URL = res.value;
        }
        apiurlLoaded = true;
        checkIfReady();
    });

    // Lade den MQTT Topic Prefix
    Shelly.call("Mqtt.GetConfig", "", function (res) {
        if (res && res.topic_prefix) {
            SHELLY_ID = res.topic_prefix;
        }
        mqttLoaded = true;
        checkIfReady();
    });

    // Prüfe, ob alle Werte geladen wurden
    function checkIfReady() {
        if (wattLoaded && keyLoaded && mqttLoaded && apiurlLoaded && !isInitialized) {
            isInitialized = true;
            print("Initialisierung abgeschlossen. Starte Timer.");
            // Starte den Timer erst hier
            Timer.set(INTERVAL_SECONDS * 1000, true, function() {
                updateDailyRunTimeAndCheck();
            });
            updateDailyRunTimeAndCheck(); // Startet sofort beim Initialisieren
        }
    }
}

// Skript-Start
initialize();



// Funktion zum Aktualisieren der KVS-Daten und Senden bei Tageswechsel
function updateDailyRunTimeAndCheck() {
  let now = new Date();
  let currentDate = now.getFullYear() + "-" + (now.getMonth() + 1) + "-" + now.getDate();

  Shelly.call("KVS.Get", { key: "RunTimeDate" }, function(res) {
    if (!res || (res && res.value !== currentDate)) { // neuer Tag
      print('new day: ',currentDate);
      Shelly.call("KVS.Set", { key: "RunTimeDate", value: currentDate }, function() {
        Shelly.call("KVS.Set", { key: "DailyRunTime", value: '0' }, function() {
          continueAfterRuntimeUpdate(currentDate);
        });
      });
    } else {
      continueAfterRuntimeUpdate(currentDate);
    }
  });
}

function continueAfterRuntimeUpdate(currentDate) {
    // Schritt 1: Hole den aktuellen Wert der Laufzeit aus dem KVS
    Shelly.call("KVS.Get", { key: "DailyRunTime" }, function(res) {
        let currentRunTime = 0;
        // Stelle sicher, dass der Wert existiert und gültig ist
        if (res && res.value) {
            currentRunTime = parseInt(res.value, 10);
        }

        // Schritt 2: Prüfe die Leistung und inkrementiere, falls der Verbraucher eingeschalten ist
        let currentPower = Shelly.getComponentStatus('switch:0').apower
        if ( currentPower > min_running_watt) {
            currentRunTime += INTERVAL_SECONDS;
            print(currentDate, ': ', currentRunTime, ' (min: ', min_running_watt,'W | current: ',currentPower,'W )');
            // Speichere den neuen Wert sofort zurück ins KVS
            Shelly.call("KVS.Set", { key: "DailyRunTime", value: currentRunTime.toString() }, function() {
                send2db(currentDate,currentRunTime); 
            });
        }

        // Schritt 3: Veröffentliche den aktualisierten Wert via MQTT, falls aktiviert
        if (typeof SHELLY_ID !== "undefined" && MQTTpublish === true) {
            let payload = {
                dailyruntime:  parseFloat((currentRunTime / 3600).toFixed(2))
            };
            let jsonPayload = JSON.stringify(payload);
            MQTT.publish(SHELLY_ID + "/metrics", jsonPayload, 0, false);
        }
    });
}

function send2db(currentDate, currentRunTime){

  let apiuri = RAILS_API_URL + '/api/v1/daily_runtime';
  let headers = {
      'Content-Type': 'application/json',
      'X-Api-Key': X_Api_Key
  };
  let body = JSON.stringify({
    "device_id": DEVICE_ID,
    "day": currentDate,
    "runtime": currentRunTime
  });
  Shelly.call("HTTP.Request", {
      url: apiuri,
      method: "POST", 
      headers: headers,
      body: body,
      timeout: 2
  }, function(result, error_code, error_message) {
      if (error_code != 0) {
          print("Fehler beim Senden des Requests: " + error_message);
      }
  });

}

