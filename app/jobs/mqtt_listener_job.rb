# app/jobs/mqtt_publisher_job.rb
class MqttListenerJob < ApplicationJob
  queue_as :mqtt_listener # Definiert eine dedizierte Warteschlange für diesen Job

  def perform
    # Setzt einen Signal-Handler, um auf SIGINT (Ctrl+C) und SIGTERM zu reagieren
    # und eine Instanzvariable zu setzen, die die Schleife beendet.
    @should_stop = false
    trap_signals

    Rails.logger.info "Starting MQTT listener loop..."
    begin
      # Stellt die Verbindung zum MQTT-Broker her

      MQTT::Client.connect(Rails.application.credentials.mqtts) do |client|
        break if @should_stop
        client.get('c4set/#') do |topic, message|
          break if @should_stop
          #Rails.logger.info "device: #{topic}"
          actual_dev = device_list.find{|d| topic == d[:topic]}
          next if actual_dev.nil?
          # Robuste Fehlerbehandlung für den JSON-Parser
          begin
            m = JSON.parse(message)
          rescue JSON::ParserError => e
            Rails.logger.warn "Skipping invalid JSON message from topic '#{topic}': #{message.inspect}. Error: #{e.message}"
            next # Überspringt die aktuelle fehlerhafte Nachricht
          end
          topic = actual_dev[:device]
          next if m[actual_dev[:param]].nil?
          Rails.logger.info "device: #{topic}: #{m[actual_dev[:param]]} #{actual_dev[:unit]}"
          case topic
          when 'pump-mode'
            pump_mode = m[actual_dev[:param]]
            ConfigDb.set('pump_mode', pump_mode.to_s)
            ShellyApi.set_kvs(ShellyApi.get_ip('poolcontrol'), "PumpMode", pump_mode)
          when 'min-solar-power'
            min_solar_power = m[actual_dev[:param]]
            ConfigDb.set('min_solar_power', min_solar_power.to_s)
            ShellyApi.set_kvs(ShellyApi.get_ip('poolcontrol'), "MinSolarPowerPumpRun", min_solar_power)
          when 'max-market-price'
            max_market_price = m[actual_dev[:param]]
            ConfigDb.set('max_market_price', max_market_price.to_s)
            ShellyApi.set_kvs(ShellyApi.get_ip('poolcontrol'), "MaxMarketPrice", max_market_price)
          when 'limit_pump_runtime'
            limit_pump_runtime = m[actual_dev[:param]]
            ConfigDb.set('limit_pump_runtime', limit_pump_runtime.to_s)
            ShellyApi.set_kvs(ShellyApi.get_ip('poolcontrol'), "LimitPumpRuntime", limit_pump_runtime)
          when 'solarlimit'
            solarlimit = m[actual_dev[:param]]
            Opendtu.setlimit(solarlimit)
            Rails.logger.info("set hoymiles limit to: #{solarlimit}%")
          end
        end
      end

    rescue MQTT::Exception => e
      # Behandelt Fehler wie Verbindungsabbrüche und versucht die Verbindung neu herzustellen
      Rails.logger.error "MQTT connection error: #{e.message}. Retrying in 5 seconds..."
      # Unterbricht das Warten, wenn ein Signal empfangen wird.
      sleep(5) unless @should_stop
    rescue => e
      # Behandelt andere unerwartete Fehler
      Rails.logger.error "An unexpected error occurred: #{e.message}. Retrying in 10 seconds..."
      # Unterbricht das Warten, wenn ein Signal empfangen wird.
      sleep(10) unless @should_stop
    end

    Rails.logger.info "MQTT listener loop finished gracefully."
  end

  private

  def device_list
    [
      {device: 'pump-mode',            topic: 'c4set/pump-mode',                param: 'mode',   unit: 'on'},
      {device: 'min-solar-power',      topic: 'c4set/min-solar-power',          param: 'power',  unit: 'Watt'},
      {device: 'max-market-price',     topic: 'c4set/max-market-price',         param: 'cent',   unit: 'Cent'},
      {device: 'limit_pump_runtime',   topic: 'c4set/limit-pump-runtime',       param: 'hours',  unit: 'Hours'},
      {device: 'solarlimit',           topic: 'c4set/solarlimit',               param: 'value',  unit: 'Percent'}
    ]
  end


  # Richtet die Signal-Handler für sauberes Beenden ein.
  def trap_signals
    Signal.trap('INT') { @should_stop = true }  # Fängt Ctrl+C ab
    Signal.trap('TERM') { @should_stop = true } # Fängt Beendigungs-Signale ab
  end


end
