// let TARGET_SHELLY_IP = "192.168.0.119";  plug 2 neu
let TARGET_SHELLY_IP = "192.168.0.13";  // outdoor plug pool
let TARGET_SHELLY_RELAY_ID = 0; // Die ID des Relais, normalerweise 0 für Shelly Plug S oder den ersten Ausgang
let INTERVAL_SECONDS = 10; //alle 10 sekunden checken
let log = 1;
let SHELLY_ID = undefined;
let MQTTpublish = true;

Shelly.call("Mqtt.GetConfig", "", function (res, err_code, err_msg, ud) {
  if (res && res.topic_prefix) {
    SHELLY_ID = res.topic_prefix;
    if (log > 0) print("MQTT Topic Prefix (SHELLY_ID):", SHELLY_ID);
  } else if (log > 0) {
    print("MQTT Topic Prefix konnte nicht ermittelt werden. Code:", err_code, "Msg:", err_msg);
  }
});

// Funktion zum Schalten des Shelly-Relais
function setShellyRelay(state) {
  let url = "http://" + TARGET_SHELLY_IP + "/rpc/Switch.Set";
  let body = JSON.stringify({
    id: TARGET_SHELLY_RELAY_ID,
    on: state
  });

  Shelly.call("HTTP.POST", {
    url: url,
    body: body,
    headers: { "Content-Type": "application/json" }
   }, function(result, error_code, error_message) {
    if (error_code === 0) {
      if(log > 1){
        print("Shelly Relais auf " + ((state ? 'EIN' : 'AUS')) + " geschaltet.");
      }
    } else {
      print("Fehler beim Schalten des Shelly Relais: " + error_message);
    }
  });
}

function updateDailyRunTime() {

  let d = new Date();
  let day = d.getDate().toString();
  Shelly.call("KVS.Get", { key: "RunTimeDay" }, function(res) {
    if (res && res.value) {
      if (res.value !== day) { // neuer Tag erkannt
        Shelly.call("KVS.Set", { key: "RunTimeDay", value: day }, function(resCurrent) {
          Shelly.call("KVS.Set", { key: "DailyPumpRunTime", value: '0' })
        })
      }
    } else {
      Shelly.call("KVS.Set", { key: "RunTimeDay", value: day }, function(resCurrent) {
        Shelly.call("KVS.Set", { key: "DailyPumpRunTime", value: '0' })
      })
    }
  });

  Shelly.call("HTTP.GET", { url: "http://" + TARGET_SHELLY_IP + "/rpc/Shelly.GetStatus?id=" + TARGET_SHELLY_RELAY_ID }, function(result, error_code, error_message) {
    if (error_code === 0 && result && result.body) {
      let status = JSON.parse(result.body);
      let isTargetRelayOn = status["switch:" + TARGET_SHELLY_RELAY_ID.toString()].output; 
//      let isTargetRelayOn = status["switch:" + TARGET_SHELLY_RELAY_ID.toString()].apower > 300; 
      if(log > 2){
        print("Shelly Pumpe Relais Status: " + ((isTargetRelayOn)  ? 'EIN' : 'AUS'));
      }
      if (isTargetRelayOn) {
        // Aktuelle Laufzeit aus KVS lesen und INTERVAL_SECONDS hinzufügen
        Shelly.call("KVS.Get", { key: "DailyPumpRunTime" }, function(res) {
          let currentRunTime = 0;
          if (res && res.value) {
            currentRunTime = parseInt(res.value, 10);
          }
          currentRunTime += INTERVAL_SECONDS;
          Shelly.call("KVS.Set", { key: "DailyPumpRunTime", value: currentRunTime.toString() });
        });
      }
    } else {
      print( "Fehler beim Abrufen des Ziel-Shelly-Status: " +error_message);
    }
  });

}

// Funktion zum ����berprüfen der Bedingungen und Schalten
function checkAndSwitch() {
  Shelly.call("KVS.Get", { key: "CurrentSolarPowerWatts" }, function(resCurrent) {
    let currentSolarPowerWatts = parseFloat(resCurrent.value);
    
    Shelly.call("KVS.Get", { key: "MinSolarPowerPumpRun" }, function(resMin) {
      let minSolarPowerPumpRun = parseInt(resMin.value, 10);
      
      Shelly.call("KVS.Get", { key: "BoilerOn" }, function(resBoiler) {
        let BoilerOn = resBoiler.value === "true"; // KVS speichert Booleans als String
        
        Shelly.call("KVS.Get", { key: "PumpMode" }, function(resPumpMode) {
          let PumpMode = resPumpMode.value; 

          Shelly.call("KVS.Get", { key: "DailyPumpRunTime" }, function(resPumpRunTime) {
            let currentRunTime = resPumpRunTime.value ; 
            if (log > 1) {
              print("============Aktuelle Werte=============:");
              print("currentSolarPowerWatts: " + currentSolarPowerWatts);
              print("minSolarPowerPumpRun: " + minSolarPowerPumpRun);
              print("BoilerOn: " + ((BoilerOn) ? "on" : "off"));
              print("PumpMode: " + PumpMode);
              print("RunTime: "+ currentRunTime);
            }
            let shouldPumpRun = false;
            let currentRunTimeHours = currentRunTime / 3600;

            // Bedingung 1: currentSolarPowerWatts > minSolarPowerPumpRun UND BoilerOn = false
            if ((currentSolarPowerWatts > minSolarPowerPumpRun) && !BoilerOn) {
              shouldPumpRun = true;
              print("Bedingung 1 erfüllt: Genug Solarstrom und Boiler ist aus. (",currentSolarPowerWatts , "W > ", minSolarPowerPumpRun, "W) | Runtime: ",currentRunTimeHours.toFixed(2), ' hours');
            }

            // Bedingung 2: overrulePumpSwitch = true
            if (PumpMode === 'on') {
              shouldPumpRun = true;
              print("Bedingung 2 erfüllt: Manuelle Übersteuerung ist aktiv.");
            }
            
            if (shouldPumpRun === false) {
              print("pump is off");
            }
            // Schalte das Relais basierend auf shouldPumpRun
            setShellyRelay(shouldPumpRun);

            if (typeof SHELLY_ID !== "undefined" && MQTTpublish === true) {

                payload = { 
                  switch: ((shouldPumpRun) ? 'on' : 'off'),
                  current_solar: currentSolarPowerWatts,
                  min_solar_power: minSolarPowerPumpRun,
                  pump_mode: PumpMode,
                  boiler: ((BoilerOn) ? "on" : "off"),
                  daily_runtime: currentRunTimeHours.toFixed(2),
                };
                let jsonPayload = JSON.stringify(payload);
                MQTT.publish(SHELLY_ID + "/metrics", jsonPayload, 0, false);
            };

          });
        });
      });
    });
  });
}

updateDailyRunTime();
checkAndSwitch();

// Plant eine regelmäßige Überprüfung und Laufzeitaktualisierung
Timer.set(INTERVAL_SECONDS * 1000, true, function() {
  checkAndSwitch(); // Prüft die Bedingungen und schaltet ggf.
  updateDailyRunTime(); // Aktualisiert die Laufzeit
});