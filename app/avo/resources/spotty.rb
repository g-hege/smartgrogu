class Avo::Resources::Spotty < Avo::BaseResource

  self.translation_key = "avo.resource_translations.spotty"
  # self.includes = []
  # self.attachments = []
  # self.search = {
  #   query: -> { query.ransack(id_eq: q, m: "or").result(distinct: false) }
  # }
  
  def fields
    field :id, as: :id, except_on: [:forms, :index]
    field :timestamp, as: :date_time, sortable: true
    field :consumption, as: :number
    field :price, as: :number    
  end
end
