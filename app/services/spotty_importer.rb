# app/services/spotty_importer.rb
class SpottyImporter

  def self.call
    new.call
  end

  def initialize()

		# GET-Request, um die Cookies und den XSRF-Token zu erhalten
		get_uri = URI.parse('https://i.spottyenergie.at/')
		get_http = Net::HTTP.new(get_uri.host, get_uri.port)
		get_http.use_ssl = get_uri.scheme == 'https'
		get_req = Net::HTTP::Get.new(get_uri.request_uri)
		get_req['User-Agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:141.0) Gecko/20100101 Firefox/141.0'

		get_response = get_http.request(get_req)

		# Extrahiere die Cookies aus dem GET-Response
		cookies = get_response['set-cookie']
		# Extrahiere den XSRF-Token
		xsrf_token = nil
		if cookies
		  match = cookies.match(/XSRF-TOKEN=([^;]+)/)
		  xsrf_token = match[1] if match
		end

		# Splitten der Cookies in einzelne Einträge
		cookies.gsub!(',', ';')
		cookie_entries = cookies.split(';').map(&:strip)

		# Filtern der benötigten Parameter und Hinzufügen von LANG=de
		filtered_cookies = cookie_entries.map do |cookie|
		  if cookie.start_with?("JSESSIONID=")
		    "JSESSIONID=#{cookie.match(/JSESSIONID=([^;]+)/)[1]}"
		  elsif cookie.start_with?("XSRF-TOKEN=")
		    "XSRF-TOKEN=#{cookie.match(/XSRF-TOKEN=([^;]+)/)[1]}"
		  else
		    nil
		  end
		end.compact

		# Hinzufügen von LANG=de
		filtered_cookies << "LANG=de"

		# Zusammenfügen zu einem String für den Request-Header
		cookies = filtered_cookies.join('; ')

    uri = URI.parse('https://i.spottyenergie.at/api/login?remember-me=true')
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == 'https'
    req =  Net::HTTP::Post.new(uri.request_uri)

		payload = {
		  "username" => Rails.application.credentials.spotty.user,
		  "password" => Rails.application.credentials.spotty.pwd,
		  "deviceId" => Rails.application.credentials.spotty.deviceid,
		  "deviceType" => "desktop",
		  "userAgent" => "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:141.0) Gecko/20100101 Firefox/141.0",
		}.to_json

		req['Accept'] = 'application/json'
		req['Accept-Encoding'] = 'gzip, deflate, br, zstd'
		req['Accept-Language'] = 'de,en-US;q=0.7,en;q=0.3'
		req['Content-Type'] = 'application/json'
		req['Cookie'] = cookies
		req['User-Agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:141.0) Gecko/20100101 Firefox/141.0'
		req['X-UI-VERSION'] = 'ebc0d06d5'
		req['X-XSRF-TOKEN'] = xsrf_token

		req.body = payload

    response = http.request(req);

		if response.is_a?(Net::HTTPSuccess)
			if response['Content-Encoding'] == 'gzip'
			  begin
			    # Verwende StringIO, um den String wie eine Datei zu behandeln
			    gz = Zlib::GzipReader.new(StringIO.new(response.body))
			    decompressed_body = gz.read
			    retjson = JSON.parse(decompressed_body)
			  rescue Zlib::GzipFile::Error => e
			    puts "Fehler beim Dekomprimieren des Bodies: #{e.message}"
			    retjson = nil
			  end
			else
			  # Wenn nicht komprimiert, den Body direkt verarbeiten
			  retjson = JSON.parse(response.body) if response.is_a?(Net::HTTPSuccess)
			end
			set_cookie = response['set-cookie']
			match = set_cookie.match(/remember-me=([^;]+)/)
			remember_me_value = match[1] if match
			cookie_entries = cookies.split(';').map(&:strip)
			cookie_entries << "remember-me=#{remember_me_value}"
			@cookies = cookie_entries.join('; ')
		end

  end

  def call
  	
		from = (Spotty.maximum(:timestamp) + 1.day).strftime("%Y-%m-%d")
		to = Time.now.in_time_zone('Europe/Vienna').to_date.strftime("%Y-%m-%d")
  	uri = "https://i.spottyenergie.at/api/contracts/#{Rails.application.credentials.spotty.contracts}/export-consumption-data?meics=#{Rails.application.credentials.spotty.meics}&startDate=#{from}&endDate=#{to}"
		get_uri = URI.parse(uri)
		get_http = Net::HTTP.new(get_uri.host, get_uri.port)
		get_http.use_ssl = get_uri.scheme == 'https'
		get_req = Net::HTTP::Get.new(get_uri.request_uri)
		get_req['User-Agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:141.0) Gecko/20100101 Firefox/141.0'
		get_req['Accept'] = 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8'
		get_req['Accept-Encoding'] = 'gzip, deflate, br, zstd'
		get_req['Accept-Language'] = 'de,en-US;q=0.7,en;q=0.3'
		get_req['Connection'] = 'keep-alive'
		get_req['Cookie'] = @cookies

		storage_dir = Rails.root.join('storage', 'spotty')
		FileUtils.mkdir_p(storage_dir) unless Dir.exist?(storage_dir)
		file_path = storage_dir.join('spooty_export.xlsx')

		Net::HTTP.start(get_uri.host, get_uri.port, use_ssl: true) do |http|
			http.request(get_req) do |response|
			# Check if the response is successful
				if response.is_a?(Net::HTTPSuccess)
				  # Ensure the entire body is read
				  File.open(file_path, 'wb') do |file|
				    response.read_body do |chunk|
				      file.write(chunk)
				    end
				  end
				  puts "File saved successfully."
				  import_excel()
				else
				  puts "Request failed with status: #{response.code}"
				end
			end
		end
  end

  def import_excel

		storage_dir = Rails.root.join('storage', 'spotty')
		file_path = storage_dir.join('spooty_export.xlsx')
#		file_path = storage_dir.join('Export 2025.xlsx')

		Zip.warn_invalid_date = false
		xlsx = Roo::Excelx.new(file_path)

    import_count = 0
    update_count = 0

		(1..xlsx.last_row).each do |row|
			record = xlsx.row(row)
			if record[1].kind_of? Date
				vienna_time = Time.parse(record[1].strftime("%Y-%m-%d %H:%M:%S"))
				puts "#{vienna_time} #{record[2]} #{record[4]}"
        consumption_value = record[2].to_f
        price_value = record[4].to_f
        spotty_record = Spotty.find_or_initialize_by(timestamp: vienna_time)
        if spotty_record.persisted?
          spotty_record.update!(consumption: consumption_value, price: price_value)
          update_count += 1
        else
          spotty_record.consumption = consumption_value
          spotty_record.price = price_value
          spotty_record.save!
          import_count += 1
        end
			end
		end


puts "🏁 Import abgeschlossen! #{import_count} neue Datensätze importiert, #{update_count} Datensätze aktualisiert."

  end


end


