// Konfiguration
let REMOTE_SHELLY_IP = "192.168.0.6"; // Die IP-Adresse des Shelly, dessen Verbrauch gemessen werden soll
let KVS_KEY = "BoilerOn"; // Der Schlüssel, unter dem der Wert gespeichert wird
let POWER_ON_THRESHOLT = 1000; // Stromverbrauch größer, wird als ON erkannt
let SWITCH_NAME = 'Boiler'
let INTERVAL_SECONDS = 10; // Wie oft der Wert abgerufen werden soll (in Sekunden)
let log = 0;

function getRemotePowerConsumption() {
    Shelly.call(
        "HTTP.GET",
        {
            url: "http://" + REMOTE_SHELLY_IP + "/rpc/Switch.GetStatus?id=0",
            timeout: 5 
        },
        function (res, err_code, msg, ud) {
            if (err_code === 0) { // HTTP-Anfrage erfolgreich
                try {
                    let responseData = JSON.parse(res.body);
                    if (responseData  && typeof responseData.apower === 'number') {
                        let switchStatus = (responseData.apower > POWER_ON_THRESHOLT) ? true : false;
                        if(log > 0){
                            print(SWITCH_NAME + " Status: " + ((switchStatus) ? 'On' : 'Off'));
                        }
                        Shelly.call(
                            "KVS.Set",
                            {
                                key: KVS_KEY,
                                value: switchStatus,
                                is_volatile: false // Wert bleibt nach Neustart erhalten (true löscht ihn)
                            },
                            function (res_kvs, err_code_kvs, msg_kvs, ud_kvs) {
                                if (err_code_kvs === 0) {
                                    if(log > 0){
                                        print(SWITCH_NAME + " KVS[ "+ KVS_KEY + " ] --> " +  ((switchStatus) ? 'On' : 'Off'));
                                    }
                                } else {
                                    print("Fehler beim Setzen des KVS-Werts: " + msg_kvs + "(Code: " + err_code_kvs + ")");
                                }
                            }
                        );
                    } else {
                        print("Ungültige oder fehlende 'apower' im RPC-Status des Remote-Shellys.");
                    }
                } catch (e) {
                    print("Fehler beim Parsen der JSON-Antwort vom Remote-Shelly:", e);
                }
            } else {
                print("Fehler beim Abrufen des Verbrauchs vom Remote-Shelly (" + REMOTE_SHELLY_IP  + "): " + msg +  "(Code: " + err_code);
            }
        },
        null // user_data
    );
}

// Skript starten und alle X Sekunden wiederholen
Timer.set(INTERVAL_SECONDS * 1000, true, getRemotePowerConsumption);

// Optional: Sofortigen Aufruf beim Skriptstart
getRemotePowerConsumption();