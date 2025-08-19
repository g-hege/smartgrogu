// Dieser Skript misst die kumulierte Einschaltzeit eines Shelly-Plugs pro Tag
// und sendet die Daten eine Ruby-on-Rails-App

let RAILS_API_URL = "https://ihre-rails-app.com/api/shelly_data"; 

let INTERVAL_SECONDS = 10; // check every 10 seconds
let MIN_RUNNING_WATT = 350; // minimal  Watt 

let MQTTpublish = true;
let SHELLY_ID = undefined;

let log = 1;

Shelly.call("Mqtt.GetConfig", "", function (res, err_code, err_msg, ud) {
  if (res && res.topic_prefix) {
    SHELLY_ID = res.topic_prefix;
    if (log > 0) print("MQTT Topic Prefix (SHELLY_ID):", SHELLY_ID);
  } else if (log > 0) {
    print("MQTT topic prefix could not be determined. Code:", err_code, "Msg:", err_msg);
  }
});


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
        if (Shelly.getComponentStatus('switch:0').apower > MIN_RUNNING_WATT) {
            currentRunTime += INTERVAL_SECONDS;
            print(currentDate, ': ', currentRunTime);

            // Speichere den neuen Wert sofort zurück ins KVS
            Shelly.call("KVS.Set", { key: "DailyRunTime", value: currentRunTime.toString() }, function() {
                // checkAndSwitch(); 
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

Timer.set(INTERVAL_SECONDS * 1000, true, function() {
  updateDailyRunTimeAndCheck();
});

updateDailyRunTimeAndCheck();