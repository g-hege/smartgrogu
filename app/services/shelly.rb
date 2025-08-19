# app/services/shelly_api.rb

class Shelly

  def self.set_kvs(shellyurl, key, value)
    new.set_kvs(shellyurl, key, value)
  end

  def self.get_ip(device)
      ip = nil
      selectdevice = Rails.application.credentials.shelly.device.find{|c|c[0]==device.to_sym}
      ip = selectdevice[1].ip if !selectdevice.nil?
      ip
  end

  def self.init_kvs
    ConfigData.where.not(kvs_key: nil).each do |c|
      new.set_kvs(get_ip(c.shelly_kvs_device), c.kvs_key, c.value)
    end;
    'done'
  end

  def set_kvs(shellyurl, key, value)
    uri = URI("http://#{shellyurl}/rpc")

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = false

    request = create_request(uri, key, value)
    response = http.request(request)

    handle_response(response, key, value)
  end


  private


  def create_request(uri, key, value)
    request = Net::HTTP::Post.new(uri.path, { 'Content-Type' => 'application/json' })
    data = {
      id: 1,
      src: 'smartgrogu',
      method: 'KVS.Set',
      params: {
        key: key,
        value: value,
        delete_after: 0,
        is_volatile: false
      }
    }
    request.body = data.to_json
    request
  end


  def handle_response(response, key, value)
    if response.is_a?(Net::HTTPSuccess)
      # Erfolgreicher Request (2xx Statuscode)
      Rails.logger.info "Shelly: Erfolgreich KVS[#{key}] auf #{value} gesetzt."
      return true
    elsif response.is_a?(Net::HTTPClientError)
      # Client-Fehler (4xx Statuscode)
      Rails.logger.error "Shelly Client-Fehler: #{response.code} #{response.message} #{response.body}"
    elsif response.is_a?(Net::HTTPServerError)
      # Server-Fehler (5xx Statuscode)
      Rails.logger.error "Shelly Server-Fehler: #{response.code} #{response.message} #{response.body}"
    else
      # Andere Fehler oder Weiterleitungen (z.B. 3xx)
      Rails.logger.error "Shelly Unbekannter Fehler: #{response.code} #{response.message} #{response.body}"
    end
    false
  end
end
