let TARGET_SHELLY_IP = "192.168.0.13";  // outdoor plug pool
let TARGET_SHELLY_RELAY_ID = 0; 
let INTERVAL_SECONDS = 10; // check every 10 seconds
let log = 1;
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
        print("Shelly Relay " + ((state) ? 'ON' : 'OFF'));
      }
    } else {
      print("Error Shelly Relay post: " + error_message);
    }
  });
}

function updateDailyRunTime() {

  let d = new Date();
  let day = d.getDate().toString();
  Shelly.call("KVS.Get", { key: "RunTimeDay" }, function(res) {
    if (res && res.value) {
      if (res.value !== day) { // new day
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
      print( "Error get Shelly status: " +error_message);
    }
  });

}

function checkAndSwitch() {

  let kvsValuesToLoad = [
    { key: 'CurrentSolarPowerWatts', callback: function(value) {currentSolarPowerWatts = value}, default: 1},
    { key: 'MinSolarPowerPumpRun', callback: function(value) {minSolarPowerPumpRun = value}, default: 451},
    { key: 'BoilerOn', callback: function(value) {BoilerOn = value}, default: 'false'},
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

          if (log > 1) {
            print("============Current values=============:");
            print("currentSolarPowerWatts: " + currentSolarPowerWatts);
            print("minSolarPowerPumpRun: " + minSolarPowerPumpRun);
            print("BoilerOn: " + ((BoilerOn) ? "on" : "off"));
            print("PumpMode: " + PumpMode);
            print("RunTime: "+ currentRunTime);
            print('MaxMarketPrice: ', maxMarketPrice);
            print('CurrentMarketPrice: ', currentMarketPrice);
            print('LimitPumpRuntime: ', limitPumpRuntime);
          }
            let shouldPumpRun = false;
            let currentRunTimeHours = currentRunTime / 3600;
            let switchCondition = -1;

            // condition 1: currentSolarPowerWatts > minSolarPowerPumpRun UND BoilerOn = false
            if ((currentSolarPowerWatts > minSolarPowerPumpRun) && !BoilerOn) {
              switchCondition = 'solar';
              shouldPumpRun = true;
              print("condition 1 fulfilled: enough solar power and the boiler is off. (",currentSolarPowerWatts , "W > ", minSolarPowerPumpRun, "W) | Runtime: ",currentRunTimeHours.toFixed(2), ' hours');
            }

            // condition 2: price ok
            if (currentMarketPrice <= maxMarketPrice && currentRunTimeHours <= limitPumpRuntime){
              switchCondition = 'price';
              shouldPumpRun = true;
              print("condition 2 fulfilled: currentMarketPrice: ",currentMarketPrice, ' cent <= MaxMarketPrice: ', maxMarketPrice, ' cent | runtime: ',currentRunTimeHours.toFixed(2), ' < ', limitPumpRuntime, ' Stunden' );
            }

            // condition 3: overrulePumpSwitch = true
            if (PumpMode === 'on') {
              switchCondition = 'override';              
              shouldPumpRun = true;
              print("condition 3 fulfilled: manual override");
            }
            
            if (shouldPumpRun === false) {
              print("pump is off");
              switchCondition = 'off';
            }

            setShellyRelay(shouldPumpRun);

            if (typeof SHELLY_ID !== "undefined" && MQTTpublish === true) {
                payload = { 
                  switch: ((shouldPumpRun) ? 'on' : 'off'),
                  switchCondition: switchCondition,
                  current_solar: currentSolarPowerWatts,
                  min_solar_power: minSolarPowerPumpRun,
                  boiler_on: ((BoilerOn) ? "on" : "off"),
                  pump_mode: PumpMode,
                  boiler: ((BoilerOn) ? "on" : "off"),
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

updateDailyRunTime();
checkAndSwitch();


Timer.set(INTERVAL_SECONDS * 1000, true, function() {
  checkAndSwitch(); 
  updateDailyRunTime();
});