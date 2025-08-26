class Avo::Resources::Crypto < Avo::BaseResource

    self.translation_key = "avo.resource_translations.crypto"

  # self.includes = []
  # self.attachments = []
  # self.search = {
  #   query: -> { query.ransack(id_eq: q, m: "or").result(distinct: false) }
  # }

  self.default_sorting = {
    last_updated: :desc
  }
  
  def fields
    field :id, as: :id, except_on: [:forms, :index]
    field :name, as: :text
    field :symbol, as: :text    
    field :slug, as: :text
    field :last_updated, as: :date_time, sortable: true
    field :price, as: :number 
  end
end
