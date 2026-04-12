class Opendtu
  # Bequemer Zugriff von außen
  def self.setlimit(limit)
    new.setlimit(limit)
  end

  def self.getlimit
  	new.getlimit
  end

  def self.getlivedata
    new.getlivedata
  end

	def getlivedata
	    uri = URI("http://#{config.ip}/api/livedata/status")
	    
	    request = Net::HTTP::Get.new(uri)
	    request.basic_auth 'admin', config.pwd

	    response = Net::HTTP.start(uri.host, uri.port) { |http| http.request(request) }

	    if response.is_a?(Net::HTTPSuccess)
	      data = JSON.parse(response.body)
	      
	      # Suche im Array 'inverters' nach der passenden Serial
	      inverter = data["inverters"].find { |inv| inv["serial"] == config.serial.to_s }
	      
	      if inverter
	        {
	          reachable: inverter["reachable"],
	          producing: inverter["producing"],
	          power_total: data.dig("total", "Power", "v"), # Aktuelle Gesamtleistung
	          yield_day: data.dig("total", "YieldDay", "v"), # Tagesertrag
	          yield_total: data.dig("total", "YieldTotal", "v"), # Ertrag total im kWh
	          limit_relative: inverter["limit_relative"],
	          limit_absolute: inverter["limit_absolute"]
	        }
	      else
	        Rails.logger.error "Opendtu: Inverter mit Serial #{config.serial} nicht in Livedaten gefunden."
	        nil
	      end
	    else
	      Rails.logger.error "Opendtu Live-Data Fehler: #{response.code}"
	      nil
	    end
	  rescue => e
	    Rails.logger.error "Opendtu Live-Data Exception: #{e.message}"
	    nil
	end


  def getlimit
    uri = URI("http://#{config.ip}/api/limit/status")
    
    request = Net::HTTP::Get.new(uri)
    request.basic_auth 'admin', config.pwd

    response = Net::HTTP.start(uri.host, uri.port) { |http| http.request(request) }

    if response.is_a?(Net::HTTPSuccess)
      data = JSON.parse(response.body)
      # Wir greifen auf die Seriennummer aus den Credentials zu
      dtu_data = data[config.serial.to_s]
      
      if dtu_data
        Rails.logger.info "Opendtu Limit: #{dtu_data['limit_relative']}%"
        return dtu_data["limit_relative"]
      else
        Rails.logger.error "Opendtu: Seriennummer #{config.serial} nicht in Antwort gefunden."
        nil
      end
    else
      Rails.logger.error "Opendtu Get Fehler: #{response.code}"
      nil
    end
  rescue => e
    Rails.logger.error "Opendtu Exception: #{e.message}"
    nil
  end

  def setlimit(limit)
    uri = URI("http://#{config.ip}/api/limit/config")
    
    # HTTP-Client vorbereiten
    http = Net::HTTP.new(uri.host, uri.port)
    
    request = Net::HTTP::Post.new(uri.path)
    request.basic_auth 'admin', config.pwd
    request["Content-Type"] = "application/x-www-form-urlencoded"

    json_data = {
      serial: config.serial,
      limit_type: 3, # RelativPersistent
      limit_value: limit.to_i
    }.to_json
    
    request.body = "data=#{ERB::Util.url_encode(json_data)}"

    response = http.request(request)
    handle_response(response)
  end

  private

  # Hilfsmethode, um den Zugriff auf Credentials zu verkürzen
  def config
    Rails.application.credentials.opendtu
  end

  def handle_response(response)
    case response
    when Net::HTTPSuccess
      parsed = JSON.parse(response.body)
      if parsed["type"] == "success"
        Rails.logger.info "Opendtu Success: #{parsed["message"]}"
        true
      else
        Rails.logger.error "Opendtu API Error: #{parsed["message"]}"
        false
      end
    else
      Rails.logger.error "Opendtu HTTP Error: #{response.code} - #{response.message}"
      false
    end
  rescue JSON::ParserError
    Rails.logger.error "Opendtu: Ungültiges JSON vom Device"
    false
  end
end