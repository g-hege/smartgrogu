class Avo::Resources::Epex < Avo::BaseResource
  self.title = 'test'
#  self.resource_name = "EPEX Spot Preise"
  # self.includes = []
  # self.attachments = []
  # self.search = {
  #   query: -> { query.ransack(id_eq: q, m: "or").result(distinct: false) }
  # }
  
  def fields
    field :id, as: :id, except_on: [:forms, :index]
    field :timestamp, as: :date_time, sortable: true
    field :marketprice, as: :number
  end
end
