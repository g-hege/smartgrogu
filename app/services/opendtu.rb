# app/services/opendtu.rp

class Opendtu

	def self.setlimit(limit)
		new.setlimit(limit)
	end

	def setlimit(limit)
		uri = URI("http://#{Rails.application.credentials.opendtu.ip}/api/limit/config")
	    request = Net::HTTP::Post.new uri.path
	    request.basic_auth 'admin', Rails.application.credentials.opendtu.pwd

#limit_type = 0 AbsoluteNonPersistent
#limit_type = 1 RelativeNonPersistent
#limit_type = 256 AbsolutePersistent
#limit_type = 257 RelativePersistent

	    json_data = {
	      serial: Rails.application.credentials.opendtu.serial,
	      limit_type: 257,
	      limit_value: limit,
	    }.to_json
	    
	    request.body = "data=#{json_data}"
    	http = Net::HTTP.new(uri.host, uri.port)
    	http.use_ssl = false
		response = http.request(request)
		handle_response(response,  limit)
	end

	private
	  def handle_response(response,  limit)
	    if response.is_a?(Net::HTTPSuccess)
	      # Erfolgreicher Request (2xx Statuscode)
	      Rails.logger.info "Opendtu erfolgreich auf #{limit}% gesetzt."
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