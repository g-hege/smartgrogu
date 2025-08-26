class Avo::Resources::Crypto < Avo::BaseResource

  self.translation_key = "avo.resource_crypto.config"

  # self.includes = []
  # self.attachments = []
  # self.search = {
  #   query: -> { query.ransack(id_eq: q, m: "or").result(distinct: false) }
  # }
  
  def fields
    field :id, as: :id
  end
end
