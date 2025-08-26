class Avo::Resources::DailyRuntime < Avo::BaseResource

    self.translation_key = "avo.resource_translations.daily_ruintime"
  # self.includes = []
  # self.attachments = []
  # self.search = {
  #   query: -> { query.ransack(id_eq: q, m: "or").result(distinct: false) }
  # }
  
  self.default_sort_column = :day
  self.default_sort_direction = :desc  
  def fields
    field :id, as: :id, except_on: [:forms, :index]
    field :day, as: :date, sortable: true
    field :device, as: :text
    field :runtime, as: :number
  end
end
