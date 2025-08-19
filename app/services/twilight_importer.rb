# app/services/twilight_importer.rb

class TwilightImporter
  def self.call
    new.call
  end

  def call
    begin
      response = HTTParty.get(Rails.application.credentials.sunrise_sunset_uri)

      unless response.success?
        Rails.logger.error "TwilightImporter: API call failed with status #{response.code}"
        return
      end

      api_results = response.parsed_response["results"]
      current_date = Time.now.in_time_zone('Europe/Vienna').to_date
      
      record = TwilightData.find_or_initialize_by(date: current_date)

      # Manuelle Zuordnung der Attribute mit korrekter Konvertierung
      record.sunrise = parse_time(api_results['sunrise'])
      record.sunset = parse_time(api_results['sunset'])
      record.solar_noon = parse_time(api_results['solar_noon'])
      record.civil_twilight_begin = parse_time(api_results['civil_twilight_begin'])
      record.civil_twilight_end = parse_time(api_results['civil_twilight_end'])
      record.nautical_twilight_begin = parse_time(api_results['nautical_twilight_begin'])
      record.nautical_twilight_end = parse_time(api_results['nautical_twilight_end'])
      record.astronomical_twilight_begin = parse_time(api_results['astronomical_twilight_begin'])
      record.astronomical_twilight_end = parse_time(api_results['astronomical_twilight_end'])
      record.day_length = api_results['day_length']

      if record.save
        Rails.logger.info "TwilightImporter: Successfully saved data for #{current_date}."
      else
        Rails.logger.error "TwilightImporter: Failed to save data. Errors: #{record.errors.full_messages.to_sentence}"
      end
      
    rescue => e
      Rails.logger.error "TwilightImporter: An error occurred during import: #{e.message}"
    end
  end

  private

  # Hilfsmethode, um Zeit-Strings korrekt zu parsen und zu validieren
  def parse_time(time_string)
    Time.zone.parse(time_string) rescue nil
  end
end