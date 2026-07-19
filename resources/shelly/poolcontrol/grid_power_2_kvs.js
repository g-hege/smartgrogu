// Konfiguration
let REMOTE_SHELLY_IP = "192.168.0.14"; // Nur die IP
let KVS_KEY = "CurrentGridPowerWatts"; 
let SWITCH_NAME = 'Energy';
let INTERVAL_SECONDS = 10; 
let log = 1; // Auf 1 gesetzt, damit du im Konsolen-Log siehst, was passiert

function getCurrentPowerConsumption() {
    Shelly.call(
        "HTTP.GET",
        {
            url: "http://" + REMOTE_SHELLY_IP + "/rpc/EM.GetStatus?id=0",
            timeout: 5 
        },
        function (res, err_code, msg) {
            if (err_code === 0 && res !== null) { 
                try {
                    let responseData = JSON.parse(res.body);
                    
                    // Prüfung auf korrekte Datenstruktur
                    if (responseData && typeof responseData.total_act_power !== 'undefined') {
                        let currentGridPower = responseData.total_act_power;
                        
                        if(log > 0) {
                            print(SWITCH_NAME + " - Aktuelle Leistung: " + currentGridPower + " W -> " + KVS_KEY);
                        }

                        // KVS.Set verlangt einen STRING als Value
                        Shelly.call(
                            "KVS.Set",
                            {
                                key: KVS_KEY,
                                value: JSON.stringify(currentGridPower) 
                            },
                            function (res_kvs, err_code_kvs, msg_kvs) {
                                if (err_code_kvs === 0) {
                                    if(log > 1) {
                                        print(SWITCH_NAME + " KVS [" + KVS_KEY + "] aktualisiert.");
                                    }
                                } else {
                                    print("Fehler KVS.Set: " + msg_kvs);
                                }
                            }
                        );
                    } else {
                        print("Datenformat ungültig: total_act_power nicht gefunden.");
                    }
                } catch (e) {
                    print("JSON Parse Fehler: " + e.message);
                }
            } else {
                print("HTTP Fehler: " + msg + " (Code: " + err_code + ")");
            }
        }
    );
}

// Intervall setzen
Timer.set(INTERVAL_SECONDS * 1000, true, function() {
    getCurrentPowerConsumption();
});

// Sofortstart
getCurrentPowerConsumption();