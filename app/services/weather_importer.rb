# app/weather_importer/weather_importer.rb

class WeatherImporter
  def self.call
    new.call
  end

  def call
    import_current_weather
    import_forecast
  end

  def import_current_weather
    data = fetch_data(Rails.application.credentials.openweathermap[:weather_uri])
    if data
      parsed_data = parse_current_weather_data(data)
      save_current_weather(parsed_data)
    end
  end

  def import_forecast
    data = fetch_data(Rails.application.credentials.openweathermap[:forecast_uri])
    if data
      parsed_data_list = parse_forecast_data(data)
      save_forecast(parsed_data_list)
      cleanup_old_forecasts
    end
  end

  private

  def fetch_data(uri_string)
    uri = URI.parse(uri_string)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == 'https')
    
    request = Net::HTTP::Get.new(uri.request_uri)
    request['Accept'] = 'application/json'
    
    response = http.request(request)
    
    return JSON.parse(response.body) if response.is_a?(Net::HTTPSuccess)
    nil
  rescue StandardError => e
    Rails.logger.error "Fehler beim Abrufen der Wetterdaten: #{e.message}"
    nil
  end

  def parse_current_weather_data(body)
    {
      timestamp: Time.at(body['dt']),
      main: body['weather'].first['main'],
      description: body['weather'].first['description'],
      icon: body['weather'].first['icon'],
      temp: body['main']['temp'],
      feels_like: body['main']['feels_like'],
      temp_min: body['main']['temp_min'],
      temp_max: body['main']['temp_max'],
      pressure: body['main']['pressure'],
      humidity: body['main']['humidity'],
      visibility: body['visibility'],
      wind_speed: body['wind']['speed'],
      wind_deg: body['wind']['deg'],
      clouds: body['clouds']['all']
    }
  end

  def save_current_weather(attributes)
    weather_reading = Weather.find_or_initialize_by(timestamp: attributes[:timestamp])
    weather_reading.update(attributes)
  end

  def parse_forecast_data(body)
    body['list'].map do |item|
      {
        timestamp: Time.at(item['dt']),
        main: item['weather'].first['main'],
        description: item['weather'].first['description'],
        icon: item['weather'].first['icon'],
        temp: item['main']['temp'],
        feels_like: item['main']['feels_like'],
        temp_min: item['main']['temp_min'],
        temp_max: item['main']['temp_max'],
        humidity: item['main']['humidity'],
        visibility: item['visibility'],
        wind_speed: item['wind']['speed'],
        wind_deg: item['wind']['deg'],
        clouds: item['clouds']['all']
      }
    end
  end

  def save_forecast(list)
    list.each do |attributes|
      forecast = WeatherForecast.find_or_initialize_by(timestamp: attributes[:timestamp])
      forecast.update(attributes)
    end
  end

  def cleanup_old_forecasts
    WeatherForecast.where('timestamp < ?', DateTime.now).destroy_all
  end
end