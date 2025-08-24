// Dieser Skript misst die kumulierte Einschaltzeit eines Shelly-Plugs pro Tag
// und sendet die Daten einmal täglich an eine Ruby-on-Rails-Anwendung.
//
// Variablen und Einstellungen
// Passen Sie diese an Ihre Rails-Anwendung an.
let ON_TIME_KEY = "pool";
let LAST_RUN_KEY = "2025-08-09";

// Konfigurieren Sie die URL Ihrer Rails-Anwendung und den API-Endpunkt
let RAILS_API_URL = "https://ihre-rails-app.com/api/shelly_data"; 

// Globale Variablen für die Skript-Logik
let onTimer = null;
let lastOnTime = 0;



// Funktion zum Aktualisieren der KVS-Daten und Senden bei Tageswechsel
function updateAndSend() {
    let now = new Date();
    let currentDate = now.getFullYear() + "-" + (now.getMonth() + 1) + "-" + now.getDate();

    // Liest den letzten gespeicherten Tag aus dem KVS
    KVS.get(LAST_RUN_KEY, function(lastRunDate) {
        // Liest die kumulierte Laufzeit aus dem KVS
        KVS.get(ON_TIME_KEY, function(onTimeSeconds) {
            onTimeSeconds = onTimeSeconds || 0;

            // Überprüft, ob ein neuer Tag begonnen hat
            if (lastRunDate !== currentDate) {
                print("Neuer Tag erkannt. Sende Daten des vorherigen Tages.");
                
                // Sende die Daten des vorherigen Tages
                sendDataToRails(onTimeSeconds, lastRunDate);
                
                // Setze den Zähler zurück
                KVS.set(ON_TIME_KEY, 0);
            }
            
            // Speichert das heutige Datum für den nächsten Tag
            KVS.set(LAST_RUN_KEY, currentDate);
        });
    });
}

// Timer, der jede Minute läuft, um den Zähler zu aktualisieren
Timer.set(60 * 1000, true, function() {
    // Wenn der Shelly eingeschaltet ist, addiere 60 Sekunden zur Laufzeit
    if (Shelly.getStatus().switch_0.output) {
        KVS.get(ON_TIME_KEY, function(onTimeSeconds) {
            onTimeSeconds = onTimeSeconds || 0;
            KVS.set(ON_TIME_KEY, onTimeSeconds + 60);
        });
    }
});



// Rufe die Funktion beim ersten Start auf, um den Initialzustand zu setzen
updateAndSend();