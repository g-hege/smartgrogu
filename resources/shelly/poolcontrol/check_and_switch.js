let TARGET_SHELLY_IP = "192.168.0.13";  // outdoor plug pool
let TARGET_SHELLY_RELAY_ID = 0; 
let INTERVAL_SECONDS = 10; // check every 10 seconds
let log = 2;
let SHELLY_ID = undefined;
let MQTTpublish = true;

Shelly.call("Mqtt.GetConfig", "", function (res, err_code, err_msg, ud) {
  if (res && res.topic_prefix) {
    SHELLY_ID = res.topic_prefix;
    if (log > 0) print("MQTT Topic Prefix (SHELLY_ID):", SHELLY_ID);
  } else if (log > 0) {
    print("MQTT topic prefix could not be determined. Code:", err_code, "Msg:", err_msg);
  }
});

let MAX_RETRIES = 2; // Wie oft soll bei Fehler wiederholt werden?

function setShellyRelay(state, attempt) {
  let currentAttempt = attempt || 0;
  let url = "http://" + TARGET_SHELLY_IP + "/rpc/Switch.Set";
  let body = {
    id: TARGET_SHELLY_RELAY_ID,
    on: state
  };

  Shelly.call("HTTP.POST", {
    url: url,
    body: JSON.stringify(body),
    headers: { "Content-Type": "application/json" },
    timeout: 5 // 5 Sekunden Timeout setzen
  }, 
  function(result, error_code, error_message) {
    if (error_code === 0) {
      if (log > 1) {
        print("Shelly Relay " + (state ? 'ON' : 'OFF') + " (Erfolg bei Versuch " + (currentAttempt + 1) + ")");
      }
    } else {
      print("Error Shelly Relay (" + error_message + "). Versuch: " + (currentAttempt + 1));

      // Wenn noch Versuche übrig sind, nach 2 Sekunden erneut probieren
      if (currentAttempt < MAX_RETRIES) {
        print("Starte Wiederholung in 2 Sekunden...");
        Timer.set(2000, false, function() {
          setShellyRelay(state, currentAttempt + 1);
        });
      } else {
        print("KRITISCH: Shelly nach " + (MAX_RETRIES + 1) + " Versuchen nicht erreichbar.");
      }
    }
  });
}

function updateDailyRunTimeAndCheck() {
  // 1. Zuerst die tägliche Laufzeit aktualisieren
  let d = new Date();
  let day = d.getDate().toString();

  Shelly.call("KVS.Get", { key: "RunTimeDay" }, function(res) {
    if (res && res.value !== day) { // neuer Tag
      Shelly.call("KVS.Set", { key: "RunTimeDay", value: day }, function() {
        Shelly.call("KVS.Set", { key: "DailyPumpRunTime", value: '0' }, function() {
          continueAfterRuntimeUpdate();
        });
      });
    } else {
      continueAfterRuntimeUpdate();
    }
  });
}

function continueAfterRuntimeUpdate() {
  // 2. Dann den Status des externen Shelly-Geräts abfragen
  Shelly.call("HTTP.GET", { url: "http://" + TARGET_SHELLY_IP + "/rpc/Shelly.GetStatus" }, function(result, error_code, error_message) {
    if (error_code === 0 && result && result.body) {
      let status = JSON.parse(result.body);
      let isTargetRelayOn = status["switch:" + TARGET_SHELLY_RELAY_ID.toString()].output;

      if (isTargetRelayOn) {
        Shelly.call("KVS.Get", { key: "DailyPumpRunTime" }, function(res) {
          let currentRunTime = 0;
          if (res && res.value) {
            currentRunTime = parseInt(res.value, 10);
          }
          currentRunTime += INTERVAL_SECONDS;
          Shelly.call("KVS.Set", { key: "DailyPumpRunTime", value: currentRunTime.toString() }, function() {
            // Erst wenn die Laufzeit aktualisiert wurde, fahre mit der Hauptlogik fort
            checkAndSwitch();
          });
        });
      } else {
        checkAndSwitch(); // Auch wenn die Pumpe aus ist, die Logik ausführen
      }
    } else {
      print("Error get Shelly status: " + error_message);
      // Im Fehlerfall trotzdem versuchen, die Hauptlogik auszuführen
      checkAndSwitch();
    }
  });
}

function checkAndSwitch() {

  let kvsValuesToLoad = [
    { key: 'CurrentGridPowerWatts', callback: function(value) {currentGridPowerWatts = value}, default: 0},
    { key: 'CurrentPumpPowerWatts', callback: function(value) {currentPumpPowerWatts = value}, default: 0},
    { key: 'PumpMode', callback: function(value) {PumpMode = value}, default: 'auto'},
    { key: 'DailyPumpRunTime', callback: function(value) {currentRunTime = value}, default: 0},  
    { key: 'MaxMarketPrice', callback: function(value) {maxMarketPrice = value}, default: 20},  
    { key: 'CurrentMarketPrice', callback: function(value) {currentMarketPrice = value}, default: 19},  
    { key: 'LimitPumpRuntime', callback: function(value) {limitPumpRuntime = value}, default: 10},  
    ];

    for (let d = 0; d < kvsValuesToLoad.length; d++){
      let item = kvsValuesToLoad[d];
      item.callback(item.default); 
    }

    Shelly.call("KVS.GetMany", {"match":'*'},
      function (res, errc, errm) {
        if(errc) print(errc, errm, JSON.stringify(res));
        if(!errc) {
          let itemsStr = JSON.stringify(res.items);
          for (let d = 0; d < kvsValuesToLoad.length; d++){
            let item = kvsValuesToLoad[d];
            for (let i = 0; i < res.items.length; i++) {
              if (res.items[i].key === item.key) { 
                item.callback(res.items[i].value); 
                break; 
              }
            }
          }
  // load kvs end


            let shouldPumpRun = false;
            let pumpIsRunning = Number(currentPumpPowerWatts) > 50;
            let currentRunTimeHours = currentRunTime / 3600;
            let switchCondition = -1;

            if (pumpIsRunning) {
                // Die Pumpe läuft bereits
                if (currentGridPowerWatts > 50) {
                    shouldPumpRun = false;
                    print("Condition 1: Zu wenig Solarstrom (Netzbezug > 50W) -> Pumpe AUS. Aktueller Netzbezug: ", currentGridPowerWatts, "W");
                } else {
                    shouldPumpRun = true;
                    switchCondition = 'solar';
                }
            } else {
                // Die Pumpe ist momentan aus
                if (Number(currentGridPowerWatts) < -350) {
                    shouldPumpRun = true;
                    switchCondition = 'solar';
                    print("Condition 1: Genug Überschuss (Einspeisung > 350W) -> Pumpe AN. Aktueller Netzbezug: ", currentGridPowerWatts, "W");
                } else {
                    shouldPumpRun = false;
                }
            }

            // condition 2: price ok
            if (shouldPumpRun === false && parseInt(currentMarketPrice) <= parseInt(maxMarketPrice) && parseInt(currentRunTimeHours) <= parseInt(limitPumpRuntime)){
              switchCondition = 'price';
              shouldPumpRun = true;
              print("condition 2 fulfilled: currentMarketPrice: ",currentMarketPrice, ' cent <= MaxMarketPrice: ', maxMarketPrice, ' cent | runtime: ',currentRunTimeHours.toFixed(2), ' < ', limitPumpRuntime, ' Stunden' );
            }

            // condition 3: overrulePumpSwitch = true
            if (shouldPumpRun === false && PumpMode === 'on') {
              switchCondition = 'override';              
              shouldPumpRun = true;
              print("condition 3 fulfilled: manual override");
            }
            
            if (shouldPumpRun === false) {
              print("pump is off");
              switchCondition = 'off';
            }
   
            if(pumpIsRunning != shouldPumpRun){
                setShellyRelay(shouldPumpRun);
            }

            if (log > 1) {
                let logMessage = "============ Current values =============\n" +
                      "currentPumpPowerWatts: " + currentPumpPowerWatts + " | " +
                      "currentGridPowerWatts: " + currentGridPowerWatts + "\n" +
                      "PumpMode: " + PumpMode + " | " + 
                      "IsRunning: " + (pumpIsRunning ? "YES" : "NO") + " | " +
                      "ShouldRun: " + (shouldPumpRun ? "YES" : "NO") + " | " +
                      "RunTime: " + (currentRunTime / 3600).toFixed(2) + " | " +
                      "LimitPumpRuntime: " + limitPumpRuntime + "\n" + 
                      "MaxMarketPrice: " + maxMarketPrice + " | " +
                      "CurrentMarketPrice: " + currentMarketPrice + "\n=============";
                print(logMessage);
            }

            if (typeof SHELLY_ID !== "undefined" && MQTTpublish === true) {
                payload = { 
                  switch: ((shouldPumpRun) ? 'on' : 'off'),
                  switchCondition: switchCondition,
                  pump_mode: PumpMode,
                  max_market_price: maxMarketPrice,
                  current_market_price: currentMarketPrice,
                  daily_runtime: currentRunTimeHours.toFixed(2),
                  limitPumpRuntime: limitPumpRuntime
                };
                let jsonPayload = JSON.stringify(payload);
                MQTT.publish(SHELLY_ID + "/metrics", jsonPayload, 0, false);
            };

// load kvs callback close

        }
    }
  );
}

// Starte den Prozess im Timer
Timer.set(INTERVAL_SECONDS * 1000, true, function() {
  updateDailyRunTimeAndCheck();
});

// Initialer Start des Skripts
updateDailyRunTimeAndCheck();