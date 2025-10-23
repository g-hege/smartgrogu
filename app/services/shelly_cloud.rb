# app/service/shelly_cloud.rb

class ShellyCloud

  def self.import(singledevice =  nil, date_from = nil)
    new().import(singledevice, date_from)
  end

  def self.devicestatus(devices, status_pick)
    new().devicestatus(devices, status_pick)
  end

  def self.update_market_price
    new().update_market_price
  end

  def initialize()
    uri = URI.parse('https://api.shelly.cloud/auth/login')
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == 'https'
    req =  Net::HTTP::Post.new(uri.request_uri)
    req.set_form_data({'email' => Rails.application.credentials.shelly.user,'password' => Rails.application.credentials.shelly.pwd, 'var' => '2'})
    response = http.request(req);
    retjson = JSON.load(response.body) if response.is_a?(Net::HTTPSuccess);
    @shelly_token = retjson['data']['token'] rescue nil
    @shelly_uri = retjson['data']['user_api_url'] rescue nil
  end

  def import(singledevice = nil, date_from = nil)

    device_import_list = []
    if singledevice.nil?
      device_import_list = Rails.application.credentials.shelly.device.select do |device_name, device_data|
        device_data[:import] == true
      end.keys
    else
      selectdevice = Rails.application.credentials.shelly.device.find{|c|c[0]==singledevice.to_sym}
      device_import_list = [selectdevice[0]] if !selectdevice.nil?
    end

    if device_import_list.count == 0
      Rails.logger.error "ShellyCloud.import device: #{device} not found!"
      return nil
    end

    device_import_list.each do |device|
      Rails.logger.info "import: #{device}"
      if date_from.nil?
        import_date_from = Consumption.where(device: device.to_s).maximum(:timestamp).to_date.prev_day rescue Date.parse(Rails.application.credentials.shelly.device[device][:startdate])
      else
        import_date_from = Date.parse(date_from)
      end
      date_to = Date.today
      for import_day in import_date_from..date_to do
        total_day = import_day(device, import_day)
        Rails.logger.info "import: #{device} #{import_day.strftime('%y-%m-%d')} -> #{total_day.round(2)} W/h"
      end
    end
    'done'
  end

  def import_day(device, import_day)

    unless @shelly_token
      puts "no shelly token!"
      return nil if @shelly_token.nil?    
    end

    if import_day.kind_of? String
      import_from = Time.parse("#{import_day}")
    else
      import_from = import_day.to_time
    end

    import_to =  import_from + 23*60*60

    deviceid = Rails.application.credentials.shelly.device[device][:id] rescue nil

    return nil if deviceid.nil?
    
    param = {
      'id': deviceid,
      'channel': 0,
      'date_range': 'custom',
      'date_from': import_from.strftime("%Y-%m-%d %H:%M"),
      'date_to': import_to.strftime("%Y-%m-%d %H:%M")
    }
    if Rails.application.credentials.shelly.device[device][:type] == 'em-3p'
      uri =  URI.parse("#{@shelly_uri}/v2/statistics/power-consumption/em-3p?#{URI.encode_www_form(param)}")
    else # pm1-plus
      uri =  URI.parse("#{@shelly_uri}/v2/statistics/power-consumption?#{URI.encode_www_form(param)}")
    end
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    req =  Net::HTTP::Get.new(uri.request_uri)
    req['Authorization'] = "Bearer #{@shelly_token}"
    req['Content-type']  = 'application/json'
    req['Accept']        = 'application/json'
    response = http.request(req)
    return nil if !response.is_a?(Net::HTTPSuccess)

    body = JSON.load(response.body)

    timezone = body['timezone']

    data_in_body = 'history'
    data_in_body = 'sum' if Rails.application.credentials.shelly.device[device][:type] == 'em-3p'
    total_day = 0
#    puts body[data_in_body]
    body[data_in_body].each do |hourdata|
      next if !hourdata['missing'].nil?
      next if hourdata['tariff_id'] == '0' && Rails.application.credentials.shelly.device[device][:type] == 'em-3p'
       local_time = ActiveSupport::TimeZone[timezone].parse(hourdata['datetime'])
       datarow = Consumption.find_or_initialize_by(
        device: device, timestamp: local_time
       )
       datarow.value = hourdata['consumption']
#       puts hourdata['consumption'].to_f
       datarow.reversed = hourdata['reversed']
       datarow.cost = hourdata['cost']
       datarow.save!
       total_day += hourdata['consumption']
    end
    total_day
  end
  
#  netto: (h['price'] + 1.894) * 1.2}}


  def update_market_price

    uri = URI("#{@shelly_uri}/v2/user/pp-ltu/#{Rails.application.credentials.shelly.live_tarif_token}")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    request = Net::HTTP::Post.new(uri.path, { 'Content-Type' => 'application/json' })
    request['Authorization'] = "Bearer #{@shelly_token}"
    data = {
      price: (
        Epex
          .where('timestamp < ?', DateTime.now) ## timezone fix
          .order(timestamp: :desc)             
          .first                               
          &.marketprice                        
      ).then do |marketprice|
        if marketprice.present?
           '%.8f' % (((marketprice.to_f + 1.894) * 1.2) / 100)
        else
          nil 
        end
      end
    }
    if data[:price].nil?
      Rails.logger.error "ShellyCloud.update_market_price: current marketprice is null!"
      return nil 
    end

    request.body = data.to_json
    response = http.request(request)
    if response.is_a?(Net::HTTPSuccess)
      Rails.logger.info "#{DateTime.now.strftime('%Y-%m-%d %H:%M')}: ShellyCloud set current price to #{data[:price].to_f.to_s}€"
      true
    elsif response.is_a?(Net::HTTPClientError)
      # Client-Fehler (4xx Statuscode)
      Rails.logger.error "ShellyCloud Client-Error: #{response.code} #{response.message}"
      Rails.logger.error "body: #{response.body}"
    elsif response.is_a?(Net::HTTPServerError)
      # Server-Fehler (5xx Statuscode)
      Rails.logger.error "ShellyCloud Server-Error: #{response.code} #{response.message}"
      Rails.logger.error "body: #{response.body}"
    else
      # Andere Fehler oder Weiterleitungen (z.B. 3xx)
      Rails.logger.error "ShellyCloud Status: #{response.code} #{response.message}"
      Rails.logger.error "body: #{response.body}"
    end
    nil
  end

  def devicestatus(devices, status_pick)

      ids = devices.map {|device|
          Rails.application.credentials.shelly.device[device][:id] rescue nil
      }

      uri = URI("#{@shelly_uri}/v2/devices/api/get?auth_key=#{Rails.application.credentials.shelly.auth_key}")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      request = Net::HTTP::Post.new(uri.path, { 'Content-Type' => 'application/json' })
      request['Authorization'] = "Bearer #{@shelly_token}"
      data = {ids: ids,select: ["status"], pick: {status: status_pick}}
      request.body = data.to_json
      response = http.request(request)         
      if response.is_a?(Net::HTTPSuccess)

        body = JSON.load(response.body)
        retrec = {}
        body.each{|r|
            devicename = Rails.application.credentials.shelly.device.key(Rails.application.credentials.shelly.device.find { |k, v| v[:id] == r['id'] }&.last).to_s
            retrec[devicename] = r['status']
        }
        return retrec
      elsif response.is_a?(Net::HTTPClientError)
        # Client-Fehler (4xx Statuscode)
        Rails.logger.error "ShellyCloud Client-Error: #{response.code} #{response.message}"
        Rails.logger.error "body: #{response.body}"
      elsif response.is_a?(Net::HTTPServerError)
        # Server-Fehler (5xx Statuscode)
        Rails.logger.error "ShellyCloud Server-Error: #{response.code} #{response.message}"
        Rails.logger.error "body: #{response.body}"
      else
        # Andere Fehler oder Weiterleitungen (z.B. 3xx)
        Rails.logger.error "ShellyCloud Status: #{response.code} #{response.message}"
        Rails.logger.error "body: #{response.body}"
      end
      nil
  end

end



# note 
=begin
    curl -X POST 'https://shelly-77-eu.shelly.cloud/v2/devices/api/get?auth_key=Rails.application.credentials.shelly.auth_key' \
    -H 'Content-Type: application/json' \
    -d '{"ids":["e4b32331c504","XB137192906423351"],"select":["status"],"pick":{"status":["temperature:0"]}}'


[{"id":"e4b32331c504","type":"sensor","code":"S3SN-0U12A","gen":"G2","online":1,
"status":{"temperature:0":{"id":0,"tC":24.7,"tF":76.4}}},

{"id":"XB137192906423351","type":"sensor","code":"SBHT-003C","gen":"GBLE","online":1,
"status":{"temperature:0":{"id":0,"tC":24.4,"tF":75.92}}}]

=end