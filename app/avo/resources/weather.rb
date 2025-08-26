class Avo::Resources::Weather < Avo::BaseResource

    self.translation_key = "avo.resource_translations.weather"

  # self.includes = []
  # self.attachments = []
  # self.search = {
  #   query: -> { query.ransack(id_eq: q, m: "or").result(distinct: false) }
  # }
  self.ordering = { timestamp: :desc }
  
  def fields
    field :id, as: :id, except_on: [:forms, :index]
    field :timestamp, as: :date_time, sortable: true
    field :main, as: :text
    field :description, as: :text
    field :temp, as: :number
    field :feels_like, as: :number
    field :temp_min, as: :number    
    field :temp_max, as: :number    
    field :humidity, as: :number          
    field :wind_speed, as: :number 
    field :wind_deg, as: :number   
    field :clouds,  as: :number  
  end
end
