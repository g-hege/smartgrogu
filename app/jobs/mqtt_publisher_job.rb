# app/jobs/mqtt_publisher_job.rb
class MqttPublisherJob < ApplicationJob

  include ActionView::Helpers::DateHelper

  queue_as :mqtt_publisher # Definiert eine dedizierte Warteschlange für diesen Job

  # Wird aufgerufen, wenn der Job gestartet wird.
  def perform

    Rails.logger.info "Publishing MQTT messages at #{Time.current}"
    if Rails.env.development?
      mqtt_prefix = 'test_'
    else
      mqtt_prefix = ''
    end

    mqtt_prefix = ''

    poolcontrol_ip = Shelly.get_ip('poolcontrol')
    max_market_price = ConfigDb.get('max_market_price',0).to_i
    min_solar_power = ConfigDb.get('min_solar_power',600).to_i
    limit_pump_runtime = ConfigDb.get('limit_pump_runtime',3).to_f
    pump_mode = ConfigDb.get('pump_mode',3)

    usage_pump_this_day = (Consumption.where(device: 'pool', timestamp: Date.current.all_day).sum(:value) || 0).to_f
    solar_power_this_day = (Energy.where(day: Date.current).sum("solar_self_consumed + solar_to_grid") || 0).to_f
    energy_this_day = (Energy.where(day: Date.current).sum("grid_consumed") || 0).to_f
    send_2_grid_this_day = (Energy.where(day: Date.current).sum("solar_to_grid") || 0).to_f


    current_price = Epex.where('timestamp < ?', Time.now)
                        .order(timestamp: :desc)
                        .limit(1)
                        .pluck(:marketprice)
                        .first.to_f / 10.0 #   cent/kWh

    # `Date.today.all_day` ist die idiomatische Rails-Methode für Datumsgleichheit
    price_running_hours = Epex.where(timestamp: Date.today.all_day)
                              .where('marketprice < ?', max_market_price * 10)
                              .count

    # Ermittelt Min-, Max- und Durchschnittspreise für den heutigen Tag
    min_max_avg = Epex.find_by_sql("
    SELECT MIN(marketprice) AS min, MAX(marketprice) AS max, AVG(marketprice) AS avg
    FROM epex
    WHERE DATE(timestamp) = CURRENT_DATE
    ").first

    max_price = (min_max_avg.try(:max).to_f / 10.0).to_f rescue 'na'
    min_price = (min_max_avg.try(:min).to_f / 10.0).to_f rescue 'na'
    avg_price = (min_max_avg.try(:avg).to_f / 10.0).to_f rescue 'na'

    solar_week_data = {}
    Solarweek.all.each {|w| solar_week_data["d#{(1 + solar_week_data.count )}".to_sym] = w.solarenergie.to_f/1000}

    w = Weather.order(timestamp: :desc).first
    weather = {description: w.description,
            icon: "https://openweathermap.org/img/wn/#{w.icon}@2x.png",
            clouds: w.clouds,
            temp: w.temp.to_f,
            temp_min: w.temp_min.to_f,
            temp_max: w.temp_max.to_f,
            pressure: w.pressure,
            humidity: w.humidity,
            feels_like: w.feels_like.to_f,
            wind_speed: w.wind_speed.to_f,
            wind_deg: w.wind_deg
    }


    forecasts = WeatherForecast.
      select("timestamp::date AS forecast_date, MIN(temp) as min_temp, MAX(temp) as max_temp, MAX(wind_speed) as maxwind").
      group("timestamp::date").
      order("timestamp::date")

    forecast_arr = []
    forecasts.each do |fc|
      d = (fc.forecast_date - Date.today).to_i
      if d > 0 && d < 5
        forecast_arr << "#{Date::DAYNAMES[d]} | min: #{'%.1f' % fc.min_temp.to_f} | max: #{'%.1f' % fc.max_temp.to_f} | wind: #{'%.1f' % fc.maxwind.to_f} km/h"
      end
    end

    solar_forecast_today = (SolarForecastDay.where(day: Date.today).pluck(:pv_estimate10).first || 0).to_f
    solar_forecast_tomorrow = (SolarForecastDay.where(day: (Date.today + 1)).pluck(:pv_estimate10).first || 0).to_f

    poolcontrol_addon = Shelly.get_value(Shelly.get_ip('poolcontrol'),'Temperature.GetStatus?id=100')
    pool_temp = poolcontrol_addon['tC']

    hm_data = {}
    homematic_recording.each do |hm|
      value = Recording.where(device: hm).order(timestamp: :desc).pluck(:value).first
      hm_data[hm] = (value || 0).to_f
    end

    grogu = { uptime: distance_of_time_in_words(Rails.application.config.boot_time, Time.now) }

    begin

      MQTT::Client.connect(Rails.application.credentials.mqtts) do |client|


          client.publish("#{mqtt_prefix}c4/poolpump",  {
#                          power:  "#{ @current_pool_pump_state ? 'on' : 'off'}", 
 #                         boiler: is_boiler_on() ? 'on' : 'off',
                          pump_mode: pump_mode,
                          minsolar: "#{min_solar_power}",
                          maxprice: "#{max_market_price}",
                          limit_runtime: "#{limit_pump_runtime}"
                          }.to_json )

          client.publish("#{mqtt_prefix}c4/marketprice", {  price: current_price.round(2), 
                                       max_price: max_price.round(2), 
                                       min_price: min_price.round(2),
                                       avg_price: avg_price.round(2),
                                       running_hours: price_running_hours
                                    }.to_json  )
          client.publish("#{mqtt_prefix}c4/solarweek", solar_week_data.to_json )


          client.publish("#{mqtt_prefix}c4/currentpower",{ energy_this_day: energy_this_day.round(1),
                                       solar_power_this_day: solar_power_this_day.round(1),
                                       send_2_grid_this_day: send_2_grid_this_day.round(1),
                                       usage_pump_this_day: (usage_pump_this_day.to_f / 1000).round(1)
                                    }.to_json )          

          client.publish("#{mqtt_prefix}c4/solarforecast", {today: solar_forecast_today.round(2), tomorrow: solar_forecast_tomorrow.round(2) }.to_json )

          client.publish("#{mqtt_prefix}c4/addon", {pool_temp: pool_temp}.to_json  )

          client.publish("#{mqtt_prefix}grogu/status", grogu.to_json)

          client.publish("#{mqtt_prefix}weather", weather.to_json)

          client.publish("#{mqtt_prefix}sun", TwilightData.for_today.to_clean_json)

          forecast_arr.reverse.each do |f|
            client.publish("#{mqtt_prefix}forcast", {log: f}.to_json)
          end
          
          client.publish("#{mqtt_prefix}homematic/status", hm_data.to_json )

      end
    rescue MQTT::Exception => e
      # Behandelt Fehler wie Verbindungsabbrüche und versucht die Verbindung neu herzustellen
      Rails.logger.error "MQTT connection error: #{e.message}. Retrying in 5 seconds..."
      sleep(5)
      # Unterbricht das Warten, wenn ein Signal empfangen wird.
    rescue => e
      # Behandelt andere unerwartete Fehler
      Rails.logger.error "An unexpected error occurred: #{e.message}. Retrying in 10 seconds..."
      # Unterbricht das Warten, wenn ein Signal empfangen wird.
      sleep(10)
    end

    Rails.logger.info "MQTT publisher finished gracefully."

    GoodJob::Job.where(queue_name: 'mqtt_publisher').where.not(finished_at: nil).delete_all
    GoodJob::Execution.where(queue_name: 'mqtt_publisher').where.not(finished_at: nil).delete_all

    if GoodJob::Job.where(queue_name: 'mqtt_publisher', finished_at: nil).count == 1
      self.class.set(wait: 30.seconds).perform_later
    end

  end

  def homematic_recording
    %w{temp-garden humidity-garden temp-loggia humidity-loggia temp-wz humidity-wz}
  end


  private


end
