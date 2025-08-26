class Avo::Resources::DailyRuntime < Avo::BaseResource

  self.translation_key = "avo.resource_daily_runtime.config"
  # self.includes = []
  # self.attachments = []
  # self.search = {
  #   query: -> { query.ransack(id_eq: q, m: "or").result(distinct: false) }
  # }
  
  def fields
    field :id, as: :id, except_on: [:forms, :index]
    field :day, as: :date, sortable: true
    field :device, as: :text
    field :runtime, as: :number
  end
end
