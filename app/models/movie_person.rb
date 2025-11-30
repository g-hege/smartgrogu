class MoviePerson < ApplicationRecord
	 self.table_name = "movie_person"
	 
	 belongs_to :movie, foreign_key: :movie_id, primary_key: :tmdb_id
	 
	 # person_id ist der Fremdschlüssel in dieser Tabelle, verweist auf person
	 belongs_to :person, foreign_key: :person_id
	 
	 # Sie können Scopes zur Vereinfachung hinzufügen:
	 scope :cast, -> { where(cast_crew: 'cast').order(:order) }
	 scope :crew, -> { where(cast_crew: 'crew').order(:order) }

end
