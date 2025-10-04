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
      "Grid - Wien Energie" => wiener_netze,
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
                 .transform_keys { |month_number| Date::ABBR_MONTHNAMES[month_number] }

    solar_self = Energy.where(Arel.sql("EXTRACT(YEAR FROM day) = #{year}"))
                       .group(Arel.sql("EXTRACT(MONTH FROM day)"))
                       .sum(:solar_self_consumed)
                       .transform_keys { |month_number| Date::ABBR_MONTHNAMES[month_number] }

    solar_to_grid = Energy.where(Arel.sql("EXTRACT(YEAR FROM day) = #{year}"))
                          .group(Arel.sql("EXTRACT(MONTH FROM day)"))
                          .sum(:solar_to_grid)
                          .transform_keys { |month_number| Date::ABBR_MONTHNAMES[month_number] }

    {
      "Grid - Wien Energie" => grid,
      "Solar Eigenverbrauch" => solar_self,
      "Solar Einspeisung" => solar_to_grid
    }
  end


  def self.energy_timeline
    [
      {
        name: "Wien Energie",
        data: EnergyMonthlyView.order(:month)
               .pluck(:month, :real_wiener_netze)
               .to_h
      },
      {
        name: "Solar",
        data: EnergyMonthlyView.order(:month)
               .pluck(:month, :solar_self_consumed)
               .to_h
      },
      {
        name: "Solar wasted",
        data: EnergyMonthlyView.order(:month)
               .pluck(:month, :solar_to_grid)
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

      if year == 2022
        if month <= 6
           netto_preis_kwh = 0.093619074
           netto = grid_kwh * netto_preis_kwh
        else
           netto_preis_kwh = 0.19722386
           netto = grid_kwh * netto_preis_kwh
        end
      end
      if year == 2023
        if month <= 7
           netto_preis_kwh = 0.19722386
           netto = grid_kwh * netto_preis_kwh
        else
           netto_preis_kwh = 0.156004216
           netto = grid_kwh * netto_preis_kwh
        end
      end 

      if year == 2024
        if month <= 2
           netto_preis_kwh = 0.156004216
           netto = grid_kwh * netto_preis_kwh
        end
      end
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

      if year == 2024
        strompreisbremse = 0
        case month
        when 3
          strompreisbremse = 0 
        when 4
          strompreisbremse = 0 
        when 5
          strompreisbremse = 0          
        when 6
          strompreisbremse = 0
        when 7
          strompreisbremse = 0
        when 8 
          strompreisbremse = -2.14
        when 9
          strompreisbremse = -0.95
        when 10
          strompreisbremse = -4.31
        when 11
          strompreisbremse = -14.75
        when 12
          strompreisbremse = -15.69
        end
        stromverbrauch += strompreisbremse
      end

      netzentgelte = 0
      if year < 2025
        netznutzung_ne_7_pauschale_leistung_einfachtarif = (0.053 * grid_kwh) * ust
        netzleistung_ne_7_pauschale_leistung = ((36.0/days_in_year) * days_in_month) * ust
        netzverlustentgelt_ne_7 = (0.0087 * grid_kwh) * ust
      else
        netznutzung_ne_7_pauschale_leistung_einfachtarif = (0.074 * grid_kwh) * ust
        netzleistung_ne_7_pauschale_leistung = ((48.0/days_in_year) * days_in_month) * ust
        netzverlustentgelt_ne_7 = (0.007 * grid_kwh) * ust
      end

      netzentgelte += netznutzung_ne_7_pauschale_leistung_einfachtarif
      netzentgelte += netzleistung_ne_7_pauschale_leistung
      netzentgelte += netzverlustentgelt_ne_7

      if year >= 2025
        eag_pauschale_ne_7 = ((19.02/days_in_year)*days_in_month) * ust
        netzentgelte += eag_pauschale_ne_7

        eag_foerderbeitrag_nicht_gemessene_leistung_ne_7 = ((4.695/days_in_year) * days_in_month) * ust 
        netzentgelte += eag_foerderbeitrag_nicht_gemessene_leistung_ne_7

        eag_foerderbeitrag_netznutzung_ne_7_nicht_gemessene = (0.0074 * grid_kwh) * ust
        netzentgelte += eag_foerderbeitrag_netznutzung_ne_7_nicht_gemessene

        eag_foerderbeitrag_netzverlust_ne_7 = (0.0006 * grid_kwh) * ust
        netzentgelte += eag_foerderbeitrag_netzverlust_ne_7
      end

      messpreis_ebenenbezogen_ne_7 = ((26.16/days_in_year ) * days_in_month) * ust 
      netzentgelte += messpreis_ebenenbezogen_ne_7
# find out
      gebrauchsabgabe_nur_netz_ebenenbezogen_ne_7 = 2.24
      netzentgelte += gebrauchsabgabe_nur_netz_ebenenbezogen_ne_7

      if year >= 2025
        elektrizitätsabgabe_ohne_ebene = (0.015 * grid_kwh) * ust
      else
        elektrizitätsabgabe_ohne_ebene = (0.001 * grid_kwh) * ust        
      end
      gebuehren = elektrizitätsabgabe_ohne_ebene

      brutto = stromverbrauch + netzentgelte + gebuehren

      return {month: "#{year}-#{month}",
              grid_kwh: grid_kwh,
              stromnetto: netto,
              stromkosten: stromverbrauch,
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
          ((year == 2022 ? 06 : 01) .. (year == Date.current.year ? Date.current.month : 12 )).each do |month|

          grid_kwh = Energy.where(Arel.sql("EXTRACT(YEAR FROM day) = #{year}"))
                 .where(Arel.sql("EXTRACT(MONTH FROM day) = #{month}"))
                 .sum("COALESCE(real_wiener_netze, grid_consumed)")

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
        stromnetto: 0,
        stromkosten: 0,
        netzentgelte: 0,
        gebuehren: 0,
        brutto: 0,
        solar_self: 0,
        solar_self_price: 0
      }) do |item, hash|
        hash[:grid_kwh] += item[:grid_kwh]
        hash[:stromnetto] += item[:stromnetto]
        hash[:stromkosten] += item[:stromkosten]
        hash[:netzentgelte] += item[:netzentgelte]
        hash[:gebuehren] += item[:gebuehren]
        hash[:brutto] += item[:brutto]
        hash[:solar_self] += item[:solar_self]
        hash[:solar_self_price] += item[:solar_self_price]
      end
  end

  def self.total_data_by_year(invoicedata, year)
      totals = invoice_data.each_with_object({
        grid_kwh: 0,
        stromnetto: 0,
        stromkosten: 0,
        netzentgelte: 0,
        gebuehren: 0,
        brutto: 0,
        solar_self: 0,
        solar_self_price: 0
      }) do |item, hash|
        next if Date.strptime(item[:month], '%Y-%m').year != year
        hash[:grid_kwh] += item[:grid_kwh]
        hash[:stromnetto] += item[:stromnetto]
        hash[:stromkosten] += item[:stromkosten]
        hash[:netzentgelte] += item[:netzentgelte]
        hash[:gebuehren] += item[:gebuehren]
        hash[:brutto] += item[:brutto]
        hash[:solar_self] += item[:solar_self]
        hash[:solar_self_price] += item[:solar_self_price]
      end
  end

  def self.consumption_by_month(device)
    results = Consumption.where(device: device).group_by_month(:timestamp, last: 24, current: true).sum('value')
    ret = results.each_with_object({}) { |(date, value), hash| hash[date.strftime('%b %Y')] = (value/1000).round(2)} 
  end

  def self.consumption_by_day(device, days)
    results = Consumption.where(device: device).group_by_day(:timestamp, last: days, current: true).sum('value')
    ret = results.each_with_object({}) { |(date, value), hash| hash[date.strftime('%b %d')] = (value/1000).round(2)} 
  end

  def self.consumption_by_week(device, weeks)
    results = Consumption.where(device: device).group_by_week(:timestamp, last: weeks, current: true).sum('value')
    ret = results.each_with_object({}) { |(date, value), hash| hash[date.strftime('%b %d')] = (value/1000).round(2)} 
  end

  def self.recording_by_month(device)
    results = Recording.where(device: device).group_by_month(:timestamp, last: 24, current: true).average('value')
    ret = results.each_with_object({}) { |(date, value), hash| hash[date.strftime('%b %Y')] = value} 
  end

end
