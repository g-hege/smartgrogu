# app/services/opendtu.rp

class Opendtu

	def self.setlimit(limit)
		new.setlimit(limit)
	end

	def setlimit(limit)

		uri = URI("http://#{Rails.application.credentials.opendtu.ip}/api/limit/config")

		request = Net::HTTP::Post.new(uri.path)
		request.basic_auth 'admin', Rails.application.credentials.opendtu.pwd

		request["Content-Type"] = "application/x-www-form-urlencoded"

#limit_type = 0 AbsoluteNonPersistent
#limit_type = 1 RelativeNonPersistent
#limit_type = 256 AbsolutePersistent
#limit_type = 257 RelativePersistent

	    json_data = {
	      serial: Rails.application.credentials.opendtu.serial,
	      limit_type: 3,
	      limit_value: limit,
	    }.to_json
	    
		request.body = "data=#{ERB::Util.url_encode(json_data)}"

    	http = Net::HTTP.new(uri.host, uri.port)
    	http.use_ssl = false
		response = http.request(request)

		handle_response(response,  limit)
	end

	private
	  def handle_response(response,  limit)
	    if response.is_a?(Net::HTTPSuccess)
	      # Erfolgreicher Request (2xx Statuscode)
			parsed_response = JSON.parse(response.body)
				if parsed_response["type"] == "success"
				  Rails.logger.info "Success! Opendtu: #{parsed_response["message"]}"
				  return true
				else
				  Rails.logger.info "Error set Opendtu #{parsed_response["code"]}: #{parsed_response["message"]}"
				  return false
				end
	      return true
	    elsif response.is_a?(Net::HTTPClientError)
	      # Client-Fehler (4xx Statuscode)
	      Rails.logger.error "Opendtu Client-Fehler: #{response.code} #{response.message} #{response.body}"
	    elsif response.is_a?(Net::HTTPServerError)
	      # Server-Fehler (5xx Statuscode)
	      Rails.logger.error "Opendtu Server-Fehler: #{response.code} #{response.message} #{response.body}"
	    else
	      # Andere Fehler oder Weiterleitungen (z.B. 3xx)
	      Rails.logger.error "Opendtu Unbekannter Fehler: #{response.code} #{response.message} #{response.body}"
	    end
	    false
	  end



end