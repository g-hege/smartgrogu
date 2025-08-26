class Avo::Resources::Energy < Avo::BaseResource

  self.model_class = ::Energy
  self.name = 'Energy'
  self.plural_name = 'Energy' # Oder ein anderer passender Name

  # self.includes = []
  # self.attachments = []
  # self.search = {
  #   query: -> { query.ransack(id_eq: q, m: "or").result(distinct: false) }
  # }
  
  def fields
    field :id, as: :id, except_on: [:forms, :index]
    field :day, as: :date, sortable: true
    field :grid_consumed, as: :number
    field :real_wiener_netze, as: :number
    field :solar_self_consumed, as: :number
    field :solar_to_grid, as: :number
    field :autarky_rate, as: :number
    field :self_consumed_rate, as: :number
  end
end
