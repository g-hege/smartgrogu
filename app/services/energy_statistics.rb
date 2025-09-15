class EnergyStatistics

  # Jahreswerte
  def self.by_year

    prev_wiener_netze = {
      2015 => 9868,
      2016  => 9580,
      2017  => 8531,
      2018  => 8424,
      2019  => 8167,
      2020  => 8029,
      2021  => 7260}

    wiener_netze = prev_wiener_netze.merge(Energy.group(Arel.sql("EXTRACT(YEAR FROM day)")).sum(:real_wiener_netze).transform_keys(&:to_i))
    wiener_netze[2022] = wiener_netze[2022] + 2400

    {
      "Netzverbrauch" => wiener_netze,
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

  def self.price_calc(grid_kwh: 0 , netto: 0, month: 1, year: 2025, solar_self_consumed: 0)

#      month = 8
#      year = 2025
#      grid_kwh = 307.032
#      netto = 23.66

      ust = 1.2
      days_in_year = 365
      days_in_month = Time.days_in_month(month, year) 
      days_in_year = Date.new(year).leap? ? 366 : 365

      stromverbrauch = 0
      netto_preis_kwh = netto / grid_kwh
      stromverbrauch += netto * ust

      service_fee = (0.0149 * grid_kwh) * ust
      stromverbrauch += service_fee

      stromherkunftsnachweise = (0.003 * grid_kwh) * ust
      stromverbrauch += stromherkunftsnachweise
      
      grundgebuehr  = (0.0645 * days_in_month) * ust
      stromverbrauch += grundgebuehr

      gebrauchsabgabe_energie = (netto * 0.06) * ust
      stromverbrauch += gebrauchsabgabe_energie
#--
      netzentgelte = 0
      netznutzung_ne_7_pauschale_leistung_einfachtarif = (0.074 * grid_kwh) * ust
      netzentgelte += netznutzung_ne_7_pauschale_leistung_einfachtarif

      netzleistung_ne_7_pauschale_leistung = ((48.0/days_in_year) * days_in_month) * ust
      netzentgelte += netzleistung_ne_7_pauschale_leistung

      netzverlustentgelt_ne_7 = (0.007 * grid_kwh) * ust
      netzentgelte += netzverlustentgelt_ne_7

      eag_pauschale_ne_7 = ((19.02/days_in_year)*days_in_month) * ust
      netzentgelte += eag_pauschale_ne_7

      eag_foerderbeitrag_nicht_gemessene_leistung_ne_7 = ((4.695/days_in_year) * days_in_month) * ust 
      netzentgelte += eag_foerderbeitrag_nicht_gemessene_leistung_ne_7

      eag_foerderbeitrag_netznutzung_ne_7_nicht_gemessene = (0.0074 * grid_kwh) * ust
      netzentgelte += eag_foerderbeitrag_netznutzung_ne_7_nicht_gemessene

      eag_foerderbeitrag_netzverlust_ne_7 = (0.0006 * grid_kwh) * ust
      netzentgelte += eag_foerderbeitrag_netzverlust_ne_7

      messpreis_ebenenbezogen_ne_7 = ((26.16/days_in_year ) * days_in_month) * ust 
      netzentgelte += messpreis_ebenenbezogen_ne_7
# find out
      gebrauchsabgabe_nur_netz_ebenenbezogen_ne_7 = 2.24
      netzentgelte += gebrauchsabgabe_nur_netz_ebenenbezogen_ne_7

      elektrizitätsabgabe_ohne_ebene = (0.015 * grid_kwh) * ust
      gebuehren = elektrizitätsabgabe_ohne_ebene

      brutto = stromverbrauch + netzentgelte + gebuehren

      return {month: "#{year}-#{month}",
              grid_kwh: grid_kwh,
              stromkosten_netto: stromverbrauch,
              netzentgelte: netzentgelte,
              gebuehren: gebuehren,
              brutto: brutto,
              brutto_price_kwh: brutto / grid_kwh,
              solar_self: solar_self_consumed,
              solar_self_price: solar_self_consumed * (brutto / grid_kwh)
            }

  end

  def self.invoice_data
      total = []
      (2022..Date.current.year).each do |year|
          ((year==2022 ? 06 : 01) .. Date.current.month).each do |month|

          grid_kwh = Energy.where(Arel.sql("EXTRACT(YEAR FROM day) = #{year}"))
                 .where(Arel.sql("EXTRACT(MONTH FROM day) = #{month}"))
                 .sum(:real_wiener_netze)

          netto = Energy.where(Arel.sql("EXTRACT(YEAR FROM day) = #{year}"))
                 .where(Arel.sql("EXTRACT(MONTH FROM day) = #{month}"))
                 .sum(:grid_price_netto)
          solar_self_consumed = Energy.where(Arel.sql("EXTRACT(YEAR FROM day) = #{year}"))
                 .where(Arel.sql("EXTRACT(MONTH FROM day) = #{month}"))
                 .sum(:solar_self_consumed)

            total << price_calc(grid_kwh: grid_kwh , netto: netto, month: month, year: year, solar_self_consumed: solar_self_consumed)
          end
      end
      total
  end

  def self.total_data(invoicedata)
      totals = invoice_data.each_with_object({
        grid_kwh: 0,
        stromkosten_netto: 0,
        netzentgelte: 0,
        gebuehren: 0,
        brutto: 0,
        solar_self: 0,
        solar_self_price: 0
      }) do |item, hash|
        hash[:grid_kwh] += item[:grid_kwh]
        hash[:stromkosten_netto] += item[:stromkosten_netto]
        hash[:netzentgelte] += item[:netzentgelte]
        hash[:gebuehren] += item[:gebuehren]
        hash[:brutto] += item[:brutto]
        hash[:solar_self] += item[:solar_self]
        hash[:solar_self_price] += item[:solar_self_price]
      end
  end


end
