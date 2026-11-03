// Shelly Energiezähler Skript
// Version 1.6 - Dynamische Phase & Autarkie/Eigenverbrauch
// MODIFIZIERT: Kombiniert die einfache Phasen-Konfiguration mit der Berechnung von Autarkie & Eigenverbrauch.

// ### Konfiguration für die solare Einspeisephase ###
// Ändere diesen Wert auf 1, 2 oder 3, je nachdem, an welcher Phase der Wechselrichter angeschlossen ist.

const SOLAR_FEED_IN_PHASE = 1; // 1=Phase A (L1), 2=Phase B (L2), 3=Phase C (L3)

let RAILS_API_URL = "http://192.168.0.147:3000"; 
let X_Api_Key = '12345'

// Zähler für Netzbezug/-einspeisung (Gesamtwerte)
let energyReturnedWs = 0.0;
let energyConsumedWs = 0.0; // Gesamt-Netzbezug Ws
let energyReturnedKWh = 0.0;
let energyConsumedKWh = 0.0; // Gesamt-Netzbezug kWh

// Zähler für tägliche Werte
let dailyGridConsumedKWh = 0.0;
let dailyGridConsumedWs = 0.0;
let dailySolarSelfConsumptionKWh = 0.0;
let dailySolarWastedKWh = 0.0;
let dailySolarSelfConsumptionWs = 0.0;
let dailySolarWastedWs = 0.0;

// Globale Variable für aktuelle Solarleistung (gelesen aus KVS)
let currentSolarPower = 0.0; // in Watt

// Konstanten
const TIMER_INTERVAL_SECONDS = 1.0;

// KVS-Schlüssel und Intervalle
const KVS_KEY_SOLAR_POWER = "currentSolarPowerWatts";
const SOLAR_POWER_READ_INTERVAL_MS = 5000;

let counterSaveKVS = 0;
const SAVE_KVS_INTERVAL_CYCLES = Math.round(60 / TIMER_INTERVAL_SECONDS);

const PUBLISH_MQTT_INTERVAL_CYCLES = Math.round(10 / TIMER_INTERVAL_SECONDS);
let counterPublishMQTT = PUBLISH_MQTT_INTERVAL_CYCLES -1;

const PUBLISH_TO_DB = Math.round(10 / TIMER_INTERVAL_SECONDS);
let counterPublishToDb = PUBLISH_TO_DB -1;

let currentGridPower_W = 0; 

// Einstellungen
let log = 1; // 0=kein Log, 1=Basis-Log, 2=Detail-Log (Empfehlung: 1 für normalen Betrieb)
let MQTTpublish = true;
let updateName = true; // Für Gerätenamen-Update
let writeToApi = true;

let SHELLY_ID = undefined;
Shelly.call("Mqtt.GetConfig", "", function (res, err_code, err_msg, ud) {
  if (res && res.topic_prefix) {
    SHELLY_ID = res.topic_prefix;
    if (log > 0) print("MQTT Topic Prefix (SHELLY_ID):", SHELLY_ID);
  } else if (log > 0) {
    print("MQTT Topic Prefix konnte nicht ermittelt werden. Code:", err_code, "Msg:", err_msg);
  }
});

// ### KVS-Schreibwarteschlange ###
let kvsWriteQueue = [];
let isProcessingKVSWriteQueue = false;

function processKVSWriteQueue() {
  if (isProcessingKVSWriteQueue || kvsWriteQueue.length === 0) { return; }
  isProcessingKVSWriteQueue = true;
  let task = kvsWriteQueue[0];
  Shelly.call("KVS.Set", { "key": task.key, "value": task.value },
    function(result, error_code, error_message) {
      if (error_code !== 0 && log > 0) print("KVS.Set Fehler für Key '", task.key, "': ", error_message);
      kvsWriteQueue = kvsWriteQueue.slice(1);
      isProcessingKVSWriteQueue = false;
      processKVSWriteQueue();
    }
  );
}

function SetKVS(key, value) {
  let existingTaskIndex = -1;
  for (let i = 0; i < kvsWriteQueue.length; i++) {
    if (kvsWriteQueue[i].key === key) { existingTaskIndex = i; break; }
  }
  if (existingTaskIndex !== -1) {
    kvsWriteQueue[existingTaskIndex].value = value;
  } else {
    kvsWriteQueue.push({ "key": key, "value": value });
  }
  processKVSWriteQueue();
}

// ### Leistungsformatierung (Auto W/kW) ###
function formatPower(power) {
  if (power === null || typeof power === "undefined") return "N/A";
  if (Math.abs(power) >= 1000) { return (power / 1000).toFixed(1) + "kW"; }
  return Math.round(power) + "W";
}

function SaveAllCountersToKVS() {
  SetKVS("CurrentDate", currentDate);
  SetKVS("EnergyConsumedKWh", energyConsumedKWh.toFixed(5));
  SetKVS("EnergyReturnedKWh", energyReturnedKWh.toFixed(5));
  SetKVS("DailyGridConsumedKWh", dailyGridConsumedKWh.toFixed(5));
  SetKVS("DailySolarSelfConsumptionKWh", dailySolarSelfConsumptionKWh.toFixed(5));
  SetKVS("DailySolarWastedKWh", dailySolarWastedKWh.toFixed(5));
  if (log > 1) print("Alle Zählerstände in KVS-Queue eingereiht.");
}

// ### Laden der KVS-Werte beim Start ###
let kvsValuesToLoad = [
    { key: "RailsApiUrl", class: "string", callback: function(value) { RAILS_API_URL = value; } },  
    { key: "X-Api-Key", class: "string", callback: function(value) { X_Api_Key = value; } },  
    { key: "CurrentDate", class: "string", callback: function(value) { currentDate = value; } },
    { key: "EnergyReturnedKWh", class: "val", callback: function(value) { energyReturnedKWh = value; } },
    { key: "EnergyConsumedKWh", class: "val", callback: function(value) { energyConsumedKWh = value; } },
    { key: "DailyGridConsumedKWh", class: "val", callback: function(value) { dailyGridConsumedKWh = value; } },
    { key: "DailySolarSelfConsumptionKWh", class: "val", callback: function(value) { dailySolarSelfConsumptionKWh = value; } },
    { key: "DailySolarWastedKWh", class: "val", callback: function(value) { dailySolarWastedKWh = value; } }
];

function loadKVSSequentially(index) {
    if (index >= kvsValuesToLoad.length) { isInitialized = true; return; }
    let item = kvsValuesToLoad[index];
    Shelly.call("KVS.Get", { "key": item.key }, function(result, error_code, error_message) {
        if (error_code === 0 && result && result.value !== null) {
          let retValue;
            if(item.class === 'val'){
               retValue= Number(result.value);
            } else {
               retValue = result.value;
            }
            item.callback(retValue); 
        }
        loadKVSSequentially(index + 1);
    });
}

loadKVSSequentially(0);

let now = new Date();
let currentDate = now.getFullYear() + "-" + (now.getMonth() + 1) + "-" + now.getDate();

if (log > 0) print("Starte KVS Ladevorgang...");




// ### Solarleistung aus KVS lesen ###
function readSolarPowerFromKVS() {
    Shelly.call("KVS.Get", { key: KVS_KEY_SOLAR_POWER }, function(result, error_code, error_message) {
        if (error_code === 0 && result && typeof result.value !== "undefined" && result.value !== null) {
            let kvsSolarVal = parseFloat(result.value);
            if (!isNaN(kvsSolarVal)) { currentSolarPower = kvsSolarVal; }
            else { currentSolarPower = 0; }
        } else { currentSolarPower = 0; }
    });
}
Timer.set(SOLAR_POWER_READ_INTERVAL_MS, true, readSolarPowerFromKVS);
readSolarPowerFromKVS(); 

// ### Haupt-Timer Handler ###


function timerHandler(user_data) {

  let phase_key = "";
  if (SOLAR_FEED_IN_PHASE === 1) phase_key = "a_act_power";
  else if (SOLAR_FEED_IN_PHASE === 2) phase_key = "b_act_power";
  else if (SOLAR_FEED_IN_PHASE === 3) phase_key = "c_act_power";
  
  let em = Shelly.getComponentStatus("em", 0);
  
  if (typeof em === 'undefined' || typeof em.total_act_power === 'undefined' || (phase_key !== "" && typeof em[phase_key] === 'undefined')) {
    if (log > 0) print("Fehler: Energiemessdaten (em) nicht vollständig verfügbar.");
    return;
  }

  currentGridPower_W = em.total_act_power;
  let solar_W = currentSolarPower; 
  
  let phase_net_power_W = (phase_key !== "") ? em[phase_key] : 0;
  let phase_gross_consumption_W = phase_net_power_W + solar_W;
  
  let selfConsumptionInc_Ws = 0; let wastedInc_Ws = 0; let gridConsumedInc_Ws = 0;
  if (currentGridPower_W >= 0) { energyConsumedWs += currentGridPower_W * TIMER_INTERVAL_SECONDS; gridConsumedInc_Ws = currentGridPower_W * TIMER_INTERVAL_SECONDS; } 
  else { energyReturnedWs -= currentGridPower_W * TIMER_INTERVAL_SECONDS; }
  let houseConsumption_W = solar_W + currentGridPower_W; 

  if (solar_W > 0) { 
      if (currentGridPower_W < 0) { let netExport_W = -currentGridPower_W; selfConsumptionInc_Ws = (solar_W - netExport_W) * TIMER_INTERVAL_SECONDS; wastedInc_Ws = netExport_W * TIMER_INTERVAL_SECONDS; } 
      else { selfConsumptionInc_Ws = Math.min(solar_W, houseConsumption_W) * TIMER_INTERVAL_SECONDS; wastedInc_Ws = 0; }
  } else { selfConsumptionInc_Ws = 0; wastedInc_Ws = 0; }

  selfConsumptionInc_Ws = Math.max(0, selfConsumptionInc_Ws);
  dailyGridConsumedWs += gridConsumedInc_Ws;
  dailySolarSelfConsumptionWs += selfConsumptionInc_Ws;
  dailySolarWastedWs += wastedInc_Ws;

  let fullWhConsumed = Math.floor(energyConsumedWs / 3600); if (fullWhConsumed > 0) { energyConsumedKWh += fullWhConsumed / 1000; energyConsumedWs -= fullWhConsumed * 3600; }
  let fullWhReturned = Math.floor(energyReturnedWs / 3600); if (fullWhReturned > 0) { energyReturnedKWh += fullWhReturned / 1000; energyReturnedWs -= fullWhReturned * 3600; }
  let fullWhDailyGrid = Math.floor(dailyGridConsumedWs / 3600); if (fullWhDailyGrid > 0) { dailyGridConsumedKWh += fullWhDailyGrid / 1000; dailyGridConsumedWs -= fullWhDailyGrid * 3600; }
  let fullWhSolarSelf = Math.floor(dailySolarSelfConsumptionWs / 3600); if (fullWhSolarSelf > 0) { dailySolarSelfConsumptionKWh += fullWhSolarSelf / 1000; dailySolarSelfConsumptionWs -= fullWhSolarSelf * 3600; }
  let fullWhSolarWasted = Math.floor(dailySolarWastedWs / 3600); if (fullWhSolarWasted > 0) { dailySolarWastedKWh += fullWhSolarWasted / 1000; dailySolarWastedWs -= fullWhSolarWasted * 3600; }

  let valConsumedTotal = energyConsumedKWh.toFixed(3);
  let valReturnedTotal = energyReturnedKWh.toFixed(3);

  let valDailyGrid = dailyGridConsumedKWh.toFixed(3);
  let valSolarSelf = dailySolarSelfConsumptionKWh.toFixed(3);
  let valSolarWasted = dailySolarWastedKWh.toFixed(3);
  let valGridTotal = currentGridPower_W.toFixed(1);

  let valPhaseGrossConsumption = phase_gross_consumption_W.toFixed(1);
  let total_consumption_kwh = dailyGridConsumedKWh + dailySolarSelfConsumptionKWh;
  let autarky_rate = (total_consumption_kwh > 0) ? (dailySolarSelfConsumptionKWh / total_consumption_kwh * 100) : 0;
  let valAutarky = autarky_rate.toFixed(1);
  
  let total_generation_kwh = dailySolarSelfConsumptionKWh + dailySolarWastedKWh;
  let self_consumption_rate = (total_generation_kwh > 0) ? (dailySolarSelfConsumptionKWh / total_generation_kwh * 100) : 0;
  let valSelfConsumption = self_consumption_rate.toFixed(1);

  counterPublishToDb++;
  if (counterPublishToDb >= PUBLISH_TO_DB) {
    counterPublishToDb = 0;

    if(writeToApi) {
      let apiuri = RAILS_API_URL + '/api/v1/daily_energy';
      let headers = {
          'Content-Type': 'application/json',
          'X-Api-Key': X_Api_Key
      };
      let body = JSON.stringify({
        "day": currentDate,
        "grid_consumed": valDailyGrid,
        "solar_self_consumed": valSolarSelf,
        "solar_to_grid": valSolarWasted,
        "autarky_rate": valAutarky,
        "self_consumed_rate": valSelfConsumption
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

    let now = new Date();
    let newdate = now.getFullYear() + "-" + (now.getMonth() + 1) + "-" + now.getDate()
// new day? - reset daily counters    
    if (currentDate != newdate){
      print(">>>>>> new date");  
        currentDate = newdate;
        dailyGridConsumedKWh = 0.0; dailyGridConsumedWs = 0.0;
        dailySolarSelfConsumptionKWh = 0.0; dailySolarWastedKWh = 0.0;
        dailySolarSelfConsumptionWs = 0.0; dailySolarWastedWs = 0.0;
        counterSaveKVS = SAVE_KVS_INTERVAL_CYCLES -1;
    }
  }

  counterSaveKVS++;
  if (counterSaveKVS >= SAVE_KVS_INTERVAL_CYCLES) {
    counterSaveKVS = 0;
    SaveAllCountersToKVS();
  }

  counterPublishMQTT++;
  if (counterPublishMQTT >= PUBLISH_MQTT_INTERVAL_CYCLES) {
    counterPublishMQTT = 0;
    if (updateName) {
      let deviceName = "Akt:" + formatPower(currentGridPower_W) + " Sol:" + formatPower(currentSolarPower) + " Tag:" + dailyGridConsumedKWh.toFixed(1) + " Spar:" + dailySolarSelfConsumptionKWh.toFixed(1);
      if (deviceName.length > 63) { deviceName = deviceName.substring(0, 63); }
      Shelly.call("Sys.SetConfig", { config: { device: { name: deviceName } } });
    }
    if (typeof SHELLY_ID !== "undefined" && MQTTpublish === true) {

      let payload = {};

      payload = { consumed_total: valConsumedTotal,
                  returned_total: valReturnedTotal,
                  daily_grid_consumed: valDailyGrid,
                  daily_solar_self_consumption: valSolarSelf,
                  daily_solar_to_grid: valSolarWasted,
                  daily_autarky_rate: valAutarky,
                  daily_self_consumption_rate: valSelfConsumption,
                  grid_total: valGridTotal,
                  phase1_gross_consumption: valPhaseGrossConsumption
      }
      let jsonPayload = JSON.stringify(payload);
      MQTT.publish(SHELLY_ID + "/metrics", jsonPayload, 0, false);

      if (log > 1) print("MQTT Daten publiziert.");

    }
  }
}

Timer.set(TIMER_INTERVAL_SECONDS * 1000, true, timerHandler, null);

if (log > 0) print("EnergieCounter started");// Shelly Energiezähler Skript
