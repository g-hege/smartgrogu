class Person < ApplicationRecord
	 self.table_name = "person"

	 has_many :movie_people
	 has_many :movies, through: :movie_people
	 
end
