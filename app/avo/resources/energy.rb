class Avo::Resources::Energy < Avo::BaseResource

  self.model_class = ::Energy
  self.title = 'Energy'

  self.translation_key = "avo.resource_translations.energy"

  self.default_sort_column = :day
  self.default_sort_direction = :desc  


   def fields
    field :id, as: :id, except_on: [:forms, :index, :show]
    field :day, as: :date, sortable: true, readonly:  true
    field :grid_consumed, as: :number, readonly:  true
    field :real_wiener_netze, as: :number, readonly:  true
    field :grid_price_netto, as: :number, name: "Netto", format_display_using: -> { value.present? ? sprintf('%.2f', value) : 0},
          help:  'plus 20%', readonly:  true
#    , format_using: -> {
#      if view.form?
#        value
#      end
#    }

    field 'brutto', as: :number do 
      sprintf('%.2f', record.grid_price_netto * 1.2)
    end


    field :solar_self_consumed, as: :number, readonly:  true
    field :solar_to_grid, as: :number, readonly:  true
    field :autarky_rate, as: :number, readonly:  true
    field :self_consumed_rate, as: :number, readonly:  true
  end


end
