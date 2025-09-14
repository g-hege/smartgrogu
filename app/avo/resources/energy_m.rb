class Avo::Resources::EnergyM < Avo::Resources::ArrayResource

  
  def records
    rec = EnergyMonthlyView.order(month: :desc).to_a

    idnum = 0
    rech = []
    rec.each do |r|
      idnum += 1
      rech << {id: idnum, month: r[:month],
        real_wiener_netze: r[:real_wiener_netze],
        grid_price_netto: r[:grid_price_netto],
        solar_self_consumed: r[:solar_self_consumed],
        solar_to_grid: r[:solar_to_grid]}
    end

#    Rails.logger.info rech
    rech
  end
  
  self.title = 'Energy'
  self.translation_key = "avo.resource_translations.energymonthly"

  def fields
    field :id, as: :id
    field :month, as: :text, sortable: true
    field :real_wiener_netze, as: :number, readonly:  true, name: "Grid consumed", format_display_using: -> { value.present? ? "#{sprintf('%.2f', value)} kWh" : 0}
    field :grid_price_netto, as: :number, name: "Netto", format_display_using: -> { value.present? ? "#{sprintf('%.2f', value)} €" : 0}
    field :solar_self_consumed, as: :number, readonly:  true, format_display_using: -> { value.present? ? "#{sprintf('%.2f', value)} kWh" : 0}
    field :solar_to_grid, as: :number, readonly:  true, format_display_using: -> { value.present? ? "#{sprintf('%.2f', value)} kWh" : 0}
  end

end
