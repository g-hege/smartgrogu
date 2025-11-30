class Collection < ApplicationRecord
	self.table_name = "collection"

	has_many :movies, foreign_key: :collectionid

	
end
