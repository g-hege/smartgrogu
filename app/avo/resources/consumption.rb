class Avo::Resources::Consumption < Avo::BaseResource
  # self.includes = []
  # self.attachments = []
  # self.search = {
  #   query: -> { query.ransack(id_eq: q, m: "or").result(distinct: false) }
  # }
  
  def fields
    field :id, as: :id, except_on: [:forms, :index, :show]
    field :device, as: :text, sortable: true
    field :timestamp, as: :date_time, sortable: true
    field :value, as: :number
  end

end
