// Shelly Skript:
// 1. Ruft Solardaten von OpenDTU ab und speichert sie im KVS.
// 2. Gibt die Geräte-Laufzeit (Uptime) periodisch in der Konsole aus.
// Version 2.1 (Solar-Teil basiert auf v2.0, Uptime-Teil integriert)

// Konfiguration Solar-Abruf
var OPENDTU_API_URL = "http://192.168.0.215/api/livedata/status"; // Ihre OpenDTU API URL
var OPENDTU_FETCH_INTERVAL_MS = 5000; // Abfrageintervall für OpenDTU
var KVS_KEY_SOLAR_POWER = "CurrentSolarPowerWatts"; // KVS-Schlüssel für die aktuelle Solarleistung

// Konfiguration Uptime-Logger
var UPTIME_LOG_INTERVAL_MS = 60000; // Intervall für Laufzeit-Log in der Konsole (jede Minute)

// Allgemeine Konfiguration
var log = 0; // 0 = kein Logging, 1 = Basis-Logging, 2 = Detailliertes Logging

// Globale Variable für die aktuelle Solarleistung
var solarPower = 0; // Aktuelle Solarleistung in Watt

// ### KVS-Schreibwarteschlange (für Solar-Daten) ###
var kvsQueue = [];
var isProcessingKVS = false;

function processKVSQueue() {
  if (isProcessingKVS || kvsQueue.length === 0) return;
  
  isProcessingKVS = true;
  var nextItem = kvsQueue[0]; 
  
  Shelly.call("KVS.Set", {key: nextItem.key, value: nextItem.value}, function(result, error_code, error_message) {
    isProcessingKVS = false; 
    if (error_code !== 0 && log > 0) { // Log-Level Prüfung hinzugefügt
        print("KVS.Set Fehler für Key '", nextItem.key, "': ", error_message, " (Code: ", error_code, ")");
    } else if (log > 1 && nextItem.key === KVS_KEY_SOLAR_POWER) { // Detaillierteres Logging
        // print("Solarleistung erfolgreich im KVS gespeichert:", nextItem.value);
    }
    if (nextItem.callback) nextItem.callback(result, error_code, error_message);
    
    kvsQueue = kvsQueue.slice(1); // Erstes Element entfernen
    processKVSQueue(); 
  });
}

function SafeKVS_Set(key, value, callback) {
  var existingItemIndex = -1;
  for (var i = 0; i < kvsQueue.length; i++) {
    if (kvsQueue[i].key === key) {
      existingItemIndex = i;
      break;
    }
  }

  if (existingItemIndex !== -1) {
    kvsQueue[existingItemIndex].value = value;
    kvsQueue[existingItemIndex].callback = callback; 
    if (log > 1) print("KVS-Queue: Wert für Key '", key, "' aktualisiert.");
  } else {
    kvsQueue.push({key: key, value: value, callback: callback});
  }
  
  if (!isProcessingKVS) { 
      processKVSQueue();
  }
}

// ### Leistungsformatierung (Auto W/kW) für Solar-Log ###
function formatSolarPowerForLog(power) { // Umbenannt, um Konflikte zu vermeiden, falls eine andere formatPower benötigt wird
  if (power === null || typeof power === "undefined") return "N/A";
  if (Math.abs(power) >= 1000) {
    return (power / 1000).toFixed(1) + "kW";
  }
  return Math.round(power) + "W";
}

// ### OpenDTU-Abfrage und KVS-Speicherung ###
function fetchAndStoreSolarPower() {
  if (!OPENDTU_API_URL) {
    if (log > 0) print("Solar-Skript: OpenDTU API URL nicht konfiguriert.");
    solarPower = 0;
    SafeKVS_Set(KVS_KEY_SOLAR_POWER, solarPower.toFixed(0)); 
    return;
  }

  if (log > 1) print("Solar-Skript: Rufe Solardaten von OpenDTU ab...");

  Shelly.call("HTTP.GET", {
    url: OPENDTU_API_URL,
    timeout: Math.max(4, Math.floor(OPENDTU_FETCH_INTERVAL_MS / 1000) - 1) 
  }, function(response, error_code, error_message) {
    var currentSolarValue = 0.0;

    if (error_code !== 0 || !response || !response.body) {
      if (log > 0) print("Solar-Skript: OpenDTU Fehler:", error_message || "Keine Antwort oder leerer Body. Code:", error_code);
      currentSolarValue = 0.0;
    } else {
      try {
        var data = JSON.parse(response.body);
        if (data && data.total && data.total.Power && typeof data.total.Power.v !== "undefined") {
          currentSolarValue = parseFloat(data.total.Power.v) || 0;
        } else if (data && data.inverters && Array.isArray(data.inverters)) {
          var sumPower = 0;
          for (var i = 0; i < data.inverters.length; i++) {
              if(data.inverters[i] && data.inverters[i].P_AC && typeof data.inverters[i].P_AC.v !== "undefined") {
                   sumPower += parseFloat(data.inverters[i].P_AC.v) || 0;
              }
          }
          currentSolarValue = sumPower;
          if (log > 0 && data.inverters.length > 0) print("Solar-Skript: Solarleistung von", data.inverters.length, "Wechselrichter(n) summiert.");
        }
        else {
          if (log > 0) print("Solar-Skript: OpenDTU Parse-Warnung: Pfad zur Solarleistung nicht in JSON-Antwort gefunden. Solarleistung auf 0 gesetzt.");
          currentSolarValue = 0.0;
        }
      } catch(e) {
        if (log > 0) print("Solar-Skript: OpenDTU Parse-Fehler:", e.toString());
        currentSolarValue = 0.0;
      }
    }
    
    solarPower = currentSolarValue;
    SafeKVS_Set(KVS_KEY_SOLAR_POWER, solarPower.toFixed(0)); 

    if (log > 0) print("Solar-Skript: Aktuelle Solarleistung:", formatSolarPowerForLog(solarPower), "-> KVS [", KVS_KEY_SOLAR_POWER, "]");
  });
}

// ### Uptime Logger Funktionen (integriert) ###

// ### Manuelle Padding-Funktion (Ersatz für padStart) ###
function manualPadStart(str, targetLength, padString) {
  str = String(str);
  padString = String((typeof padString !== 'undefined' ? padString : ' '));
  if (str.length >= targetLength) {
    return str;
  }
  var padding = "";
  var charsToPad = targetLength - str.length;
  while (padding.length < charsToPad) {
    padding += padString;
  }
  return padding.slice(0, charsToPad) + str;
}

// ### Laufzeitformatierung ###
function formatUptime(ms) {
  if (typeof ms !== 'number' || isNaN(ms)) {
    return "Ungültige Zeit";
  }
  var totalSeconds = Math.floor(ms / 1000);
  var days = Math.floor(totalSeconds / (24 * 60 * 60));
  totalSeconds %= (24 * 60 * 60);
  var hours = Math.floor(totalSeconds / (60 * 60));
  totalSeconds %= (60 * 60);
  var minutes = Math.floor(totalSeconds / 60);
  var seconds = totalSeconds % 60;

  var uptimeString = "";
  if (days > 0) {
    uptimeString += days + " Tag(e), ";
  }
  uptimeString += manualPadStart(String(hours), 2, '0') + "Std:" +
                  manualPadStart(String(minutes), 2, '0') + "Min:" +
                  manualPadStart(String(seconds), 2, '0') + "Sek";
  
  return uptimeString;
}

// ### Konsolen-Log der Geräte-Laufzeit ###
function logDeviceUptime() {
    if (log > 0) { // Verwendet die globale 'log' Variable
        Shelly.call("Shelly.GetStatus", {}, function(statusResult, errorCode, errorMessage) {
            if (errorCode === 0 && statusResult && typeof statusResult.sys !== "undefined" && typeof statusResult.sys.uptime !== "undefined") {
                var deviceUptimeMs = statusResult.sys.uptime * 1000; // uptime ist in Sekunden
                print("Uptime-Logger: Geräte-Laufzeit:", formatUptime(deviceUptimeMs));
            } else {
                print("Uptime-Logger: Fehler beim Abrufen der Geräte-Laufzeit. Code:", errorCode, "Msg:", errorMessage);
            }
        });
    }
}
// ### Ende Uptime Logger Funktionen ###


// ### Initialisierung des Skripts ###
if (log > 0) {
  print("Starte kombiniertes Solar KVS & Uptime Logger Skript v2.1...");
  if (!OPENDTU_API_URL && log > 0) { // Zusätzliche Prüfung für Log-Ausgabe
    print("WARNUNG: OPENDTU_API_URL ist nicht gesetzt!");
  }
}

// Erster Abruf der Solardaten beim Start
fetchAndStoreSolarPower();

// Timer für periodische Solar-Abrufe starten
Timer.set(OPENDTU_FETCH_INTERVAL_MS, true, fetchAndStoreSolarPower);

// Erster Log der Uptime beim Start
logDeviceUptime();

// Timer für periodische Uptime-Logs starten
Timer.set(UPTIME_LOG_INTERVAL_MS, true, logDeviceUptime);


if (log > 0) {
  print("Kombiniertes Skript initialisiert.");
  print("- Solardaten werden alle", OPENDTU_FETCH_INTERVAL_MS / 1000, "Sekunden abgerufen und im KVS gespeichert.");
  print("- Geräte-Laufzeit wird alle", UPTIME_LOG_INTERVAL_MS / 1000, "Sekunden in der Konsole ausgegeben.");
}