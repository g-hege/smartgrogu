let log = 1;

let kvsValuesToLoad = [
  { key: 'CurrentSolarPowerWatts', callback: function(value) {currentSolarPowerWatts = value}, default: 1},
  { key: 'MinSolarPowerPumpRun', callback: function(value) {minSolarPowerPumpRun = value}, default: 451},
  { key: 'BoilerOn', callback: function(value) {BoilerOn = value}, default: 451},
  { key: 'PumpMode', callback: function(value) {PumpMode = value}, default: 'false'},
  { key: 'DailyPumpRunTime', callback: function(value) {currentRunTime = value}, default: 0},  
  { key: 'MaxMarketPrice', callback: function(value) {maxMarketPrice = value}, default: 20},  
  { key: 'LimitPumpRuntime', callback: function(value) {limitPumpRuntime = value}, default: 10},  
  ];

  for (let d = 0; d < kvsValuesToLoad.length; d++){
    let item = kvsValuesToLoad[d];
    item.callback(item.default); 
  }

  Shelly.call("KVS.GetMany", {"match":'*'},
    function (res, errc, errm) {
      if (errc) print(errc, errm, JSON.stringify(res));
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
        if(log > 0){
          print('currentSolarPowerWatts: ', currentSolarPowerWatts)
          print('minSolarPowerPumpRun: ', minSolarPowerPumpRun);
          print('BoilerOn: ', BoilerOn);
          print('PumpMode: ', PumpMode);         
          print('DailyPumpRunTime: ', currentRunTime);
          print('MaxMarketPrice: ', maxMarketPrice);
          print('LimitPumpRuntime: ', limitPumpRuntime);
        }
      }
    }
  );