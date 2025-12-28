class Movie < ApplicationRecord

	include Elasticsearch::Model
    index_name Rails.configuration.index_movie

	self.table_name = "movie"
	self.inheritance_column = nil
 
# Da movie_person.movie_id auf movie.tmdb_id verweist:
	 has_many :movie_people, foreign_key: :movie_id, primary_key: :tmdb_id 
	 has_many :people, through: :movie_people

	 has_many :seasons, foreign_key: :movie_id, primary_key: :tmdb_id

	 belongs_to :collection, foreign_key: :collectionid, optional: true
		 
	 has_many :cast, -> { joins(:movie_people).where(movie_person: { cast_crew: 'cast' }).order('movie_person.order') }, 
	          through: :movie_people, 
	          source: :person         

	 has_many :crew, -> { joins(:movie_people).where(movie_person: { cast_crew: 'crew' }).order('movie_person.order') }, 
	          through: :movie_people, 
	          source: :person

	 has_many :ordered_seasons, -> { order(:season_number) }, 
	          class_name: 'Season', 
	          foreign_key: :movie_id, 
	          primary_key: :tmdb_id

	def genres
	    Genre.where(id: genre_ids)
    end

	def self.get_elasticsearch(es_id)
    	__elasticsearch__.client.get(index: self.index_name, id: es_id)['_source']
  	rescue Elasticsearch::Transport::Transport::Errors::NotFound
    	nil
  	end
  	

end
