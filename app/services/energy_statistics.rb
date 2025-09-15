class EnergyStatistics
  # Jahreswerte
  def self.by_year
    {
      "Netzverbrauch" => Energy.group(Arel.sql("EXTRACT(YEAR FROM day)")).sum(:real_wiener_netze).transform_keys(&:to_i),
      "Solar Eigenverbrauch" => Energy.group(Arel.sql("EXTRACT(YEAR FROM day)")).sum(:solar_self_consumed).transform_keys(&:to_i),
      "Solar Einspeisung" => Energy.group(Arel.sql("EXTRACT(YEAR FROM day)")).sum(:solar_to_grid).transform_keys(&:to_i)
    }
  end

  def self.autarkie_rate_by_year(year)
    # Gesamter Stromverbrauch aus dem Netz
      if year.nil?
        stromverbrauch = Energy.sum(:real_wiener_netze)

        # Eigenverbrauchter Solarstrom
        solar_erzeugt = Energy.sum(:solar_self_consumed)
      else
        stromverbrauch = Energy
          .where(Arel.sql("EXTRACT(YEAR FROM day) = #{year}"))
          .sum(:real_wiener_netze)

        # Eigenverbrauchter Solarstrom
        solar_erzeugt = Energy
          .where(Arel.sql("EXTRACT(YEAR FROM day) = #{year}"))
          .sum(:solar_self_consumed)

      end

      autarkie_rate = if stromverbrauch.zero?
        0
      else
        (solar_erzeugt.to_f / (stromverbrauch + solar_erzeugt) * 100).round(2)
      end    
  end


  def self.own_consumption_rate(year)
    # Gesamter Stromverbrauch aus dem Netz
      if year.nil?
        wasted_energie = Energy.sum(:solar_to_grid)

        # Eigenverbrauchter Solarstrom
        solar_erzeugt = Energy.sum(:solar_self_consumed)
      else
        wasted_energie = Energy
          .where(Arel.sql("EXTRACT(YEAR FROM day) = #{year}"))
          .sum(:solar_to_grid)

        # Eigenverbrauchter Solarstrom
        solar_erzeugt = Energy
          .where(Arel.sql("EXTRACT(YEAR FROM day) = #{year}"))
          .sum(:solar_self_consumed)

      end
      
      gesamt_solar = solar_erzeugt + wasted_energie

      eigenverbrauchsrate = if solar_erzeugt.zero?
        0
      else
        (solar_erzeugt.to_f / gesamt_solar * 100).round(2)
      end   
  end


  # Monatswerte für ein bestimmtes Jahr
  def self.by_month(year)
    grid = Energy.where(Arel.sql("EXTRACT(YEAR FROM day) = #{year}"))
                 .group(Arel.sql("EXTRACT(MONTH FROM day)"))
                 .sum(:real_wiener_netze)
                 .transform_keys(&:to_i)

    solar_self = Energy.where(Arel.sql("EXTRACT(YEAR FROM day) = #{year}"))
                       .group(Arel.sql("EXTRACT(MONTH FROM day)"))
                       .sum(:solar_self_consumed)
                       .transform_keys(&:to_i)

    solar_to_grid = Energy.where(Arel.sql("EXTRACT(YEAR FROM day) = #{year}"))
                          .group(Arel.sql("EXTRACT(MONTH FROM day)"))
                          .sum(:solar_to_grid)
                          .transform_keys(&:to_i)

    {
      "Netzverbrauch" => grid,
      "Solar Eigenverbrauch" => solar_self,
      "Solar Einspeisung" => solar_to_grid
    }
  end


  def self.energy_timeline
    [
      {
        name: "Wien Strom",
        data: EnergyMonthlyView.order(:month)
               .pluck(:month, :real_wiener_netze)
               .to_h
      },
      {
        name: "Solar",
        data: EnergyMonthlyView.order(:month)
               .pluck(:month, :solar_self_consumed)
               .to_h
      }
    ]
  end

end
