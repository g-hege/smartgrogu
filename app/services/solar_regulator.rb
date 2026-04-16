# app/services/solar_regulator.rb
class SolarRegulator
  TARGET_EXPORT = -500.0 # Watt

  def self.call
    net_power = (Shelly.get_value('energy','EM.GetStatus?id=0')["total_act_power"] rescue nil)

    dtu_data = Opendtu.getlivedata

    return if net_power.nil? || dtu_data.nil? || !dtu_data[:producing]

    current_limit_perc = dtu_data[:limit_relative] # z.B. 100
    max_power_capability = dtu_data[:limit_absolute] / (current_limit_perc / 100.0) # Was könnte er max?
    
    # Wie viel Watt exportieren wir gerade "zu viel" über das Ziel hinaus?
    # Beispiel: net_power = -700, Ziel = -500 => delta = -200 (zu viel Einspeisung)
    delta = net_power - TARGET_EXPORT

    if delta < -50 # Nur regeln, wenn Abweichung > 50W (Hysterese gegen "Flackern")
      # Wir speisen zu viel ein -> Limit senken
      new_limit_watt = dtu_data[:power_total] + delta
      new_limit_perc = (new_limit_watt / max_power_capability * 100).floor
    elsif delta > 50 && current_limit_perc < 100
      # Wir haben Puffer -> Limit erhöhen
      new_limit_watt = dtu_data[:power_total] + delta
      new_limit_perc = (new_limit_watt / max_power_capability * 100).ceil
    else
      return # Alles im grünen Bereich
    end

    # Sicherheitsschranken 0-100%
    final_limit = new_limit_perc.clamp(0, 100)

    if final_limit != current_limit_perc
      Rails.logger.info "Regelung: Netz #{net_power}W, Limit neu: #{final_limit}%"
      Opendtu.setlimit(final_limit)
    end
  end
end