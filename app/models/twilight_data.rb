class TwilightData < ApplicationRecord
  self.table_name = 'twilight_data'

  # Class method to find the record for the current day
  def self.for_today
    today = Time.now.in_time_zone('Europe/Vienna').to_date
    record = find_by(date: today)

    # Wenn der Datensatz existiert, gib ihn sofort zurück
    return record if record.present?

    # Wenn der Datensatz nicht existiert, starte den Import
    TwilightImporter.call

    # Lese den neu erstellten Datensatz aus der Datenbank und gib ihn zurück
    find_by(date: today)
  end

  # Überschreibt die Getter, um die Zeit zu formatieren
  def sunrise
    super&.strftime('%H:%M')
  end

  def sunset
    super&.strftime('%H:%M')
  end

  def solar_noon
    super&.strftime('%H:%M')
  end

  def civil_twilight_begin
    super&.strftime('%H:%M')
  end

  def civil_twilight_end
    super&.strftime('%H:%M')
  end

  def nautical_twilight_begin
    super&.strftime('%H:%M')
  end

  def nautical_twilight_end
    super&.strftime('%H:%M')
  end

  def astronomical_twilight_begin
    super&.strftime('%H:%M')
  end

  def astronomical_twilight_end
    super&.strftime('%H:%M')
  end

  def to_clean_json
    {
      date: date.to_s,
      sunrise: sunrise,
      sunset: sunset,
      solar_noon: solar_noon,
      day_length: day_length.to_s,
      civil_twilight_begin: civil_twilight_begin,
      civil_twilight_end: civil_twilight_end,
      nautical_twilight_begin: nautical_twilight_begin,
      nautical_twilight_end: nautical_twilight_end,
      astronomical_twilight_begin: astronomical_twilight_begin,
      astronomical_twilight_end: astronomical_twilight_end,
    }
  end
end