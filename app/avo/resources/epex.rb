class Avo::Resources::Epex < Avo::BaseResource


  self.translation_key = "avo.resource_translations.epex"
#  self.resource_name = "EPEX Spot Preise"
  # self.includes = []
  # self.attachments = []
  # self.search = {
  #   query: -> { query.ransack(id_eq: q, m: "or").result(distinct: false) }
  # }

  self.ordering = { timestamp: :desc }

  def fields
    field :id, as: :id, except_on: [:forms, :index]
    field :timestamp, as: :date_time, sortable: true
    field :marketprice, as: :number
  end
end
