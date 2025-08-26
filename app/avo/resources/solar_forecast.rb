class Avo::Resources::SolarForecast < Avo::BaseResource

    self.translation_key = "avo.resource_translations.solar_forecast"
  # self.includes = []
  # self.attachments = []
  # self.search = {
  #   query: -> { query.ransack(id_eq: q, m: "or").result(distinct: false) }
  # }

  self.ordering = { period_end: :desc }
  
  def fields
    field :id, as: :id, except_on: [:forms, :index, :show]
    field :period_end, as: :date_time, sortable: true
    field :pv_estimate, as: :number
    field :pv_estimate10, as: :number
    field :pv_estimate90, as: :number
  end
end
