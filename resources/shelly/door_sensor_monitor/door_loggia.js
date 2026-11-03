const SENSOR_MAC     = "fc:4d:6a:38:9f:28";  // Change this to the MAC address of your door sensor

const SIGNAL_URL     = "https://signal.callmebot.com/signal/send.php?phone=555db374-365a-4115-ba4e-f75d3c28cb23&apikey=948035&text="

let lastState = 0;  // 0=closed, 1=open (NEW: state tracking)
let lastPacketId = -1;  // dedupe

print("DOOR SENSOR SCRIPT STARTED");
BLE.Scanner.Start({active: true, duration_ms: BLE.Scanner.INFINITE_SCAN});

BLE.Scanner.Subscribe(function(event, result) {
  if (event !== BLE.Scanner.SCAN_RESULT) return;
  if (!result.service_data || !result.service_data.fcd2) return;
  if (result.addr !== SENSOR_MAC) return;

  let payload = result.service_data.fcd2;
  if (lastPacketId === payload.at(2)) return;  // skip duplicates
  lastPacketId = payload.at(2);

  // ——— PARSE BTHOME (official door/window format) ———
  let i = 1;  // skip header byte
  let battery = 0, contact = 0;  // full parser

  while (i < payload.length) {
    let obj_id = payload.at(i++);
    if (obj_id === 0x01) { battery = payload.at(i); i++; }  // battery %
    else if (obj_id === 0x2D) { contact = payload.at(i); i++; }  // window state (0=closed, 1=open)
    else { i++; }  // skip other fields (illuminance, etc.)
  }


  if (contact === 1 && lastState !== 1) {
    lastState = 1;
    print("Door Sensor Opened!");
    
    let sysStatus = Shelly.getComponentStatus("sys");
    let timeStr = "";
    
    if (sysStatus && sysStatus.time) {
      let time = sysStatus.time; // Liefert "09:54"
      let dateStr = "";
      
      // Falls .date nicht existiert, nutzen wir die Unixtime zur Berechnung
      if (sysStatus.date) {
        dateStr = sysStatus.date;
      } else if (sysStatus.unixtime) {
        // Erstellt ein JS-Date Objekt aus dem Sekunden-Zeitstempel
        let d = new Date(sysStatus.unixtime * 1000);
        let day = d.getDate();
        let month = d.getMonth() + 1; // Monate sind 0-basiert
        let year = d.getFullYear();
        
        // Führende Nullen hinzufügen für schönere Formatierung (z.B. "04.07.2026")
        if (day < 10) day = "0" + day;
        if (month < 10) month = "0" + month;
        
        dateStr = day + "." + month + "." + year;
      }
      
      timeStr = "%20" + dateStr + "%20" + time;
    }

    // 2. URL zusammenbauen (Leerzeichen sauber als %20 codiert)
    let message = "%20Loggia%20Opened" + timeStr;
    let encodedUrl = SIGNAL_URL + message;
    print(encodedUrl);

    Shelly.call("HTTP.GET", {
      url: encodedUrl,
      timeout: 30 // Gibt dem Shelly etwas mehr Zeit für den HTTPS-Handshake
    }, function(res, err) {
      if (err) {
        print("ERROR → " + err + " (Code: " + (res ? res.code : "unknown") + ")");
      } else {
        print("Signal Nachricht erfolgreich gesendet. Status: " + res.code);
      }
    });

  } else if (contact === 0) {
    lastState = 0;
    print("Door Sensor Closed.");
  }
});