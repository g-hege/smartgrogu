class Season < ApplicationRecord
	 self.table_name = "seasons"
	 belongs_to :movie, foreign_key: :movie_id, primary_key: :tmdb_id
end
