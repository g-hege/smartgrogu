class Avo::Resources::Movie < Avo::BaseResource
  # self.includes = []
  # self.attachments = []
  # self.search = {
  #   query: -> { query.ransack(id_eq: q, m: "or").result(distinct: false) }
  # }
  
  def fields
    field :id, as: :id, except_on: [:forms, :index, :show]
    field :volume, as: :text, sortable: true, readonly:  true
    field :dir, as: :text, sortable: true, readonly:  true
    field :title, as: :text, sortable: true, readonly:  true
    field :year, as: :text, sortable: true, readonly:  true
    field :resolution, as: :text, sortable: true, readonly:  true
    field :type, as: :text, sortable: true, readonly:  true
    field :size, as: :number, sortable: false, readonly:  true
  end
end
