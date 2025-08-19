# app/service/solcast_importer.rb

class SolcastImporter

  def self.call()
    new().call
  end

  def initialize()
  end

  def call

    puts "#{DateTime.now.strftime('%Y-%m-%d %M:%H')} SolarForecast update"
    uri = URI(Rails.application.credentials.solcast[:uri])
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    req =  Net::HTTP::Get.new(uri.request_uri)
    req['Authorization'] = "Bearer #{Rails.application.credentials.solcast[:apikey]}"
    req['Content-type']  = 'application/json'
    req['Accept']        = 'application/json'
    response = http.request(req)
    return nil if !response.is_a?(Net::HTTPSuccess)
   	body = JSON.load(response.body)

    body['forecasts'].each do |forecast_data|
      forecast = SolarForecast.find_or_initialize_by(
        period_end: forecast_data['period_end'] 
      )
      forecast.pv_estimate   = forecast_data['pv_estimate'] / 10
      forecast.pv_estimate10 = forecast_data['pv_estimate10'] / 10
      forecast.pv_estimate90 = forecast_data['pv_estimate90'] / 10
      forecast.save!
    end

  end

end