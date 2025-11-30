class MovieDecorator

	attr_reader :object 

	def initialize(object)
    	@object = object
	end

	def genres_name
		@object.genres.map{|g|g[:name]}
	end

	def cast
		MoviePerson.where(cast_crew: 'cast', movie_id: @object[:tmdb_id]).order(:order).map{|p|
			{person_id: p.person_id,
			name: p.person.name,
			original_name: (p.person.name != p.person.original_name ? p.person.original_name : ''),
			gender: p.person.gender,
			profile_path: p.person.profile_path,
			character: p.character,
			order: p.order,
			total_episode_count: p.total_episode_count
			}
		}

	end

	def crew
		MoviePerson.where(cast_crew: 'crew', movie_id: @object[:tmdb_id]).order(:order).map{|p|
			{person_id: p.person_id,
			name: p.person.name,
			original_name: (p.person.name != p.person.original_name ? p.person.original_name : ''),
			gender: p.person.gender,
			profile_path: p.person.profile_path,
			job: p.job,
			order: p.order,
			total_episode_count: p.total_episode_count
			}
		}

	end


	def collection
		return [] if @object.collection.nil?
		more_movies = Movie.where(collectionid: @object.collectionid).order(:release_date)
		return [] if more_movies.count == 0
		list = more_movies.map{|m|
			{id: m.tmdb_id,
				title: m.title,
				year: m.release_date.year,
				poster_path: m.poster_path
			}
		}
		{ name: @object.collection.name,
			id: @object.collection.id,
			poster_path: @object.collection.poster_path,
			movies: list
		}
	end

	def seasons
		return [] if @object.seasons.nil? 
		@object.seasons.map{|s|
			{ 	number: s.season_number,
				name: s.name,
				air_date: s.air_date,
				episode_count: s.episode_count,
				poster_path: s.poster_path,
				vote_average: s.vote_average
			}

		}
	end

  	def as_json(importkey = nil)
  		{
  			id: @object.id,
  			movie_id: @object.tmdb_id,
  			media_type: @object.media_type,
  			title: @object.title_de,
  			tagline: @object.tagline,
  			year: @object.release_date.year,
  			overview: @object.overview,
  			original_title: @object.original_title,
  			original_language: @object.original_language,
  			imdb_id: @object.imdb_id,
  			homepage: @object.homepage,
  			poster_path: @object.poster_path,
  			backdrop_path: @object.backdrop_path,
  			release_date: @object.release_date,
  			genre: genres_name,
  			genre_ids: @object.genre_ids,
  			runtime: @object.runtime,
  			youtube_trailer: @object.trailer_youtube_key,
  			vote_average: @object.vote_average,
  			vote_count: @object.vote_count,
  			keywords: @object.keywords,
  			volume: @object.volume,
  			dir: @object.volume,
  			file_name: @object.title,
  			file_type: @object.file_type,
  			resolution: @object.resolution,
  			cast: cast,
  			crew: crew,
  			seasons: seasons,
  			collection: collection,
  			index_date: Date.today,
  			importkey: importkey
  		}
  	end

end
