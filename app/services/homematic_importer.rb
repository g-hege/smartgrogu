# app/services/homematic_importer.rb
require 'json'

class HomematicImporter

HOMEMATIC_DEVICES = [
  { device: 'temp-garden', id: '3014F711A0000EDBE9923FE3', value_path: ['functionalChannels', '1', 'actualTemperature'] },
  { device: 'humidity-garden', id: '3014F711A0000EDBE9923FE3', value_path: ['functionalChannels', '1', 'humidity'] },
  { device: 'temp-loggia', id: '3014F711A0000EDBE992486B', value_path: ['functionalChannels', '1', 'actualTemperature'] },
  { device: 'humidity-loggia', id: '3014F711A0000EDBE992486B', value_path: ['functionalChannels', '1', 'humidity'] },
  { device: 'temp-wz', id: '3014F711A0000A9A499957DB', value_path: ['functionalChannels', '1', 'actualTemperature'] },
  { device: 'humidity-wz', id: '3014F711A0000A9A499957DB', value_path: ['functionalChannels', '1', 'humidity'] }
].freeze

  def self.import_actual_data
    new.import_actual_data
  end

  def self.show_labels
    new.show_labels
  end

  def import_actual_data
    puts DateTime.now.strftime('%Y-%m-%d %H:%M')

    homematic_data = fetch_homematic_data
    return unless homematic_data

    HOMEMATIC_DEVICES.each do |device_config|
      device_id = device_config[:id]
      value_path = device_config[:value_path]
      
      # Hier kommt `dig` zum Einsatz:
      value = homematic_data.dig('devices', device_id, *value_path)
      
      puts "#{device_config[:device]}: #{value}"

      Recording.create!(device: device_config[:device], value: value)
    end
  rescue StandardError => e
    Rails.logger.error "Fehler beim Homematic-Import: #{e.message}"
  end

  def show_labels
    homematic_data = fetch_homematic_data
    return unless homematic_data

    homematic_data['devices'].each do |id, device|
      puts "#{id}: #{device['label']}"
    end
  rescue StandardError => e
    Rails.logger.error "Fehler beim Anzeigen der Homematic-Labels: #{e.message}"
  end

  private

  # Führt den externen Befehl aus und gibt die JSON-Daten zurück.
  def fetch_homematic_data
    command_output = `cd /home/hege/.venv/bin; ./hmip_cli --dump-configuration`
    
    # Entfernt alles vor dem ersten JSON-Block
    json_string = command_output.sub(/^(.)*}/, '').strip
    
    JSON.parse(json_string)
  rescue StandardError => e
    Rails.logger.error "Fehler beim Abrufen der Homematic-Daten: #{e.message}"
    nil
  end


end