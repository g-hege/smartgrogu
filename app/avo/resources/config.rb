class Avo::Resources::Config < Avo::BaseResource
  self.model_class = ConfigData
  # self.includes = []
  # self.attachments = []
  # self.search = {
  #   query: -> { query.ransack(id_eq: q, m: "or").result(distinct: false) }
  # }
  
  def fields
    field :id, as: :id, except_on: [:forms, :index]
    field :config_name, as: :text, sortable: true
    field :value, as: :number
  end
end
