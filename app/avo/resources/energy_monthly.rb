class Avo::Resources::EnergyMonthly < Avo::BaseResource
  # self.includes = []
  # self.attachments = []
  # self.search = {
  #   query: -> { query.ransack(id_eq: q, m: "or").result(distinct: false) }
  # }

  self.title = 'Energy'
  self.translation_key = "avo.resource_translations.energymonthly"

  self.default_sort_column = :month
  self.default_sort_direction = :desc 

   def fields
    field :id, as: :id, except_on: [:forms, :index, :show]
    field :month, as: :text, sortable: true
    field :real_wiener_netze, as: :number, readonly:  true, name: "Grid consumed", format_display_using: -> { value.present? ? "#{sprintf('%.2f', value)} kWh" : 0}
    field :grid_price_netto, as: :number, name: "Netto", format_display_using: -> { value.present? ? "#{sprintf('%.2f', value)} €" : 0}
    field :solar_self_consumed, as: :number, readonly:  true, format_display_using: -> { value.present? ? "#{sprintf('%.2f', value)} kWh" : 0}
    field :solar_to_grid, as: :number, readonly:  true, format_display_using: -> { value.present? ? "#{sprintf('%.2f', value)} kWh" : 0}

    end

end
