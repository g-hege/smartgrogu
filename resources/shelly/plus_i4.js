// Konfiguration für das ZIEL-Shelly-Gerät (das Gerät, auf dem der KVS-Wert gesetzt werden soll)
let TARGET_SHELLY_IP = "192.168.0.15"; // <-- WICHTIG: Ersetze dies mit der tatsächlichen IP-Adresse deines ZIEL-Shellys
let KVS_KEY_TO_SET = "PumpMode"; // Der KVS-Schlüssel, der auf dem Ziel-Shelly gesetzt werden soll
let KVS_VALUE_ON_PRESS = "on"; // Der Wert, der beim Drücken gesetzt wird
// Oder du könntest einen Zeitstempel speichern:
// let KVS_VALUE_ON_PRESS = Date.now().toString(); // Zeitstempel als String

// Funktion, um einen KVS-Wert auf dem Ziel-Shelly zu setzen
function setKVSValueOnTargetShelly(value) {
  let url = "http://" + TARGET_SHELLY_IP + "/rpc/KVS.Set"; // RPC-Endpunkt zum Setzen von KVS-Werten
  let body = JSON.stringify({
    key: KVS_KEY_TO_SET,
    value: value.toString() // KVS speichert Werte als String, daher in String umwandeln
  });


  Shelly.call("HTTP.POST", {
    url: url,
    body: body,
    headers: { "Content-Type": "application/json" } // Wichtig: Inhaltstyp als JSON deklarieren
  }, function(result, error_code, error_message) {
    if (error_code === 0) {
      print("KVS-Schlüssel " + KVS_KEY_TO_SET + " erfolgreich auf Ziel-Shelly gesetzt.");
    } else {
      print("Fehler beim Setzen des KVS-Schlüssels auf Ziel-Shelly: " + error_message);
    }
  });
}

// Event-Handler für Eingangsereignisse (Tastenanschläge)
Shelly.addEventHandler(function(event) {
  print(event.info);
  if (event.info.id === 0 && (event.info.event === "btn_down" || event.info.event === "single_push")) { 
      print("Taste 1 wurde gedrückt!");
      setKVSValueOnTargetShelly("on"); 
  }

  if (event.info.id === 1 && (event.info.event === "btn_down" || event.info.event === "single_push")) { 
      print("Taste 2 wurde gedrückt!");
      setKVSValueOnTargetShelly("auto"); 
  }




});

print("Shelly Plus I4 Skript gestartet. Warte auf Drücken von Kanal 1...");