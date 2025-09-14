class Avo::Resources::EnergyJ < Avo::Resources::ArrayResource

  self.title = 'EnergyJahr'
  self.translation_key = "avo.resource_translations.energyyearly"

  def records
    rec = EnergyYearlyView.order(year: :desc).to_a

    idnum = 0
    rech = []
    rec.each do |r|
      idnum += 1
      rech << {id: idnum, year: r[:year],
        real_wiener_netze: r[:real_wiener_netze],
        grid_price_netto: r[:grid_price_netto],
        solar_self_consumed: r[:solar_self_consumed],
        solar_to_grid: r[:solar_to_grid]}
    end

    #Rails.logger.info rech
    rech
  end

  

   def fields
    field :id, as: :id
    field :year, as: :text
    field :real_wiener_netze, as: :number, readonly:  true, name: "Grid consumed", format_display_using: -> { value.present? ? "#{sprintf('%.2f', value)} kWh" : 0}
    field :grid_price_netto, as: :number, name: "Netto", format_display_using: -> { value.present? ? "#{sprintf('%.2f', value)}€" : 0}
    field :solar_self_consumed, as: :number, readonly:  true, format_display_using: -> { value.present? ? "#{sprintf('%.2f', value)} kWh" : 0}
    field :solar_to_grid, as: :number, readonly:  true, format_display_using: -> { value.present? ? "#{sprintf('%.2f', value)} kWh" : 0}

    end

end
