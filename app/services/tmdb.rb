class Tmdb

	def self.crew_selected_departments
		['Acting', 'Director', 'Screenplay', 'Writer', 'Novel', 'Writer', 'Story']
	end

	def self.get(command: nil, params: nil, api_version: 3)
		base_url = "https://api.themoviedb.org/#{api_version}/#{command}"
		query_string = URI.encode_www_form(params)
		uri = URI("#{base_url}?#{query_string}")
	    http = Net::HTTP.new(uri.host, uri.port)
	    http.use_ssl = true
	    req =  Net::HTTP::Get.new(uri.request_uri)
	    req['Authorization'] = "Bearer #{Rails.application.credentials.themoviedb[:token]}"
	    req['Content-type']  = 'application/json'
	    req['Accept']        = 'application/json'
	    response = http.request(req)
		if response.is_a?(Net::HTTPSuccess)
 			data = JSON.parse(response.body)
 		else
 			data = nil
		end
		data
	end

	def self.search(title)

		params = {
		  query: title,
		  include_adult: false,
		  language: 'de-DE',
		  page: 1
		}
		data = Tmdb.get(command: 'search/multi', params: params)
		if data['results'].count > 0
			rows = []
			data['results'].each do |m|
				title = m['title'].nil? ? m['name'] :  m['title']
				original_title = m['original_title'].nil? ? m['original_nam'] : m['original_title']
				rows <<[m['id'], title, original_title, ((Date.parse m['release_date']).strftime('%Y') rescue '')]
			end
			table = Terminal::Table.new :rows => rows
			puts table
		end

	end


	def self.getmovie(tmdb_id)
		params = { language: 'de-DE'}
		data = Tmdb.get(command: "movie/#{tmdb_id}", params: params)
		if data['overview'] == ''
			data_e = Tmdb.get(command: "movie/#{tmdb_id}", params: { language: 'en-US'})
			data['overview'] = data_e['overview']
		end
		data_external_ids = Tmdb.get(command: "movie/#{tmdb_id}/external_ids", params: params)		
		data.merge!(data_external_ids)
		data_credits = Tmdb.get(command: "movie/#{tmdb_id}/credits", params: params)	
		data.merge!(data_credits)
		data_keywords = Tmdb.get(command: "movie/#{tmdb_id}/keywords", params: {})	
		data.merge!(data_keywords)

		['de-DE','en-US'].each {|language|
			data_videos = Tmdb.get(command: "movie/#{tmdb_id}/videos", params: { language: language})
			if data_videos['results'].count > 0
				data['videos'] = data_videos['results']
				break
			end
		}
		data

	end

	def self.gettv(tmdb_id)
		params = { language: 'de-DE'}
		data = Tmdb.get(command: "tv/#{tmdb_id}", params: params)
		if data['overview'] == ''
			data_e = Tmdb.get(command: "tv/#{tmdb_id}", params: { language: 'en-US'})
			data['overview'] = data_e['overview']
		end

		data_external_ids = Tmdb.get(command: "tv/#{tmdb_id}/external_ids", params: params)	
		data.merge!(data_external_ids)
		data_credits = Tmdb.get(command: "tv/#{tmdb_id}/aggregate_credits", params: params)	
		data.merge!(data_credits)
		data_keywords = Tmdb.get(command: "tv/#{tmdb_id}/keywords", params: {})	
		data['keywords'] = data_keywords['results']
		['de-DE','en-US'].each {|language|
			data_videos = Tmdb.get(command: "tv/#{tmdb_id}/videos", params: { language: language})
			if data_videos['results'].count > 0
				data['videos'] = data_videos['results']
				break
			end
		}
		data
	end



	def self.loop(loopcnt = 10)
		Movie.where(done: false).limit(loopcnt).each do |movie|
			if movie.tmdb_id.first == 'm'
				media_type = 'movie'

			elsif movie.tmdb_id.first == 't'
				media_type = 'tv'
			else
				next
			end

			tmdb_id = movie.tmdb_id[1..99].to_i
			movie_id = movie.id
	  		puts "Titel: #{movie.title}, movieid: #{movie.id} | tmdb_id: #{tmdb_id} | media_type: #{media_type}"
			update_movie_with_tmdb(movieid: movie_id, tmdb_id: tmdb_id , media_type: media_type)

		end;
		'done'
	end

 # movieid =  1143; tmdb_id=  52256; media_type=  'movie';

# underworld  data = Tmdb.getmovie(538411)
# doc martin  data = Tmdb.gettv(2430)
# grimm  data = Tmdb.gettv(39351)

# Tmdb.update_movie_with_tmdb(media_type: 'movie', movieid: 5013, tmdb_id: 1366)
# media_type =  'tv'; movieid= 5816; tmdb_id= 2430;

# Tmdb.reset_moviedata(id: 124)
# Tmdb.update_movie_with_tmdb(media_type: 'movie', movieid: 124, tmdb_id: 244786)

# media_type =  'tv'; movieid= 5817; tmdb_id= 39351;
# Tmdb.update_movie_with_tmdb(media_type: 'tv', movieid: 5817, tmdb_id: 39351)

	def self.update_movie_with_tmdb(movieid: nil, tmdb_id: nil, media_type: 'movie', reset_persons: false)

		if media_type == 'movie'
			data = Tmdb.getmovie(tmdb_id)
			id_pre_char = 'm' ## Movie
		elsif media_type == 'tv'
			data = Tmdb.gettv(tmdb_id)
			id_pre_char = 't' ## (TV / Serie)
		end

		ret = nil
		if !data.nil?
			movie = Movie.find_by(id: movieid)
			if movie

				if reset_persons || 
					MoviePerson.destroy_by(movie_id: movie[:tmdb_id])
				end

				if !data['genres'].nil?
					Tmdb.update_genre(data['genres'])
					genres = data['genres'].map{|g|g['id']}
				else
					genres = []
				end
				if !data['belongs_to_collection'].nil?
					Tmdb.update_collection(data['belongs_to_collection'])
					collectionid = data['belongs_to_collection']['id']
				else
					collectionid = nil
				end

				release_date = (Date.parse data['release_date']) if !data['release_date'].nil?
				release_date = (Date.parse data['first_air_date']) if !data['first_air_date'].nil?

				title_de = data['title'] if !data['title'].nil?
				title_de = data['name'] if !data['name'].nil?
				original_title = data['original_title'] if !data['original_title'].nil?
				original_title = data['original_name'] if !data['original_name'].nil?

				keywords = data['keywords'].map{|k|k['name']}

 				number_of_episodes = nil
 				number_of_seasons = nil
				number_of_episodes = data['number_of_episodes'].to_i if !data['number_of_episodes'].nil?
				number_of_seasons = data['number_of_seasons'].to_i if !data['number_of_seasons'].nil?

				trailer_youtube_key = nil
				if !data['videos'].nil?
 					trailerdata = data['videos'].select{ |v| v['type']=='Trailer' && v['site'] == "YouTube"}.first
	 				if !trailerdata.nil?
	 					trailer_youtube_key = trailerdata['key']					
	 				end
	 			end

				rec = { tmdb_id: "#{id_pre_char}#{data['id']}",
						imdb_id: data['imdb_id'],
						title_de: title_de,
						original_title: original_title,
						original_language: data['original_language'],
						overview: data['overview'],
						poster_path: data['poster_path'],
						backdrop_path: data['backdrop_path'],
						media_type: media_type,
						genre_ids: genres,
						keywords: keywords,
						release_date: release_date,
						runtime: data['runtime'],
						homepage: data['homepage'],
						collectionid: collectionid,
						updated_at: DateTime.now,
						number_of_episodes: number_of_episodes,
						number_of_seasons: number_of_seasons,
						trailer_youtube_key: trailer_youtube_key,
						tagline: data['tagline'],
						vote_average: data['vote_average'],
						vote_count: data['vote_count'],
						done: true

				}
				movie.update(rec)



				persons = data['cast'].map{|p|{id: p['id'], name: p['name'], original_name: p['original_name'], gender: p['gender'], profile_path: p['profile_path']}}

				data['crew'].each { |p|
					if Tmdb.crew_selected_departments.include?(p['job']) || (!p['jobs'].nil? && Tmdb.crew_selected_departments.include?(p['jobs'].first['job']))
						persons << {id: p['id'], name: p['name'], original_name: p['original_name'], gender: p['gender'], profile_path: p['profile_path']}
					end;			
				}

				persons.uniq { |person| person[:id] }
				persons_ids = persons.map{ |p|p[:id] }
				existing_persons_ids = Person.where(id: persons_ids).pluck(:id)
				missing_ids = persons_ids - existing_persons_ids
				missing_persons_data = persons.select { |g| missing_ids.include?(g[:id]) }
				if missing_persons_data.any?
					Person.insert_all(missing_persons_data)
				end

#			MoviePerson.destroy_by(movie_id: movie[:tmdb_id])

				persons_data = []

				data['cast'].each {|p|
					total_episode_count =  p['total_episode_count'].nil? ? 1 : p['total_episode_count']
					if !p['roles'].nil?
						character = p['roles'].first['character']
					else
						character = p['character']
					end
					persons_data << {movie_id: movie[:tmdb_id], person_id: p['id'], cast_crew: 'cast', job: p['known_for_department'], order: p['order'], character: character, total_episode_count: total_episode_count}
				}

				data['crew'].each { |p|

					if !p['jobs'].nil? 
						job = p['jobs'].first['job']
					else
						job = p['job']
					end

					total_episode_count =  p['total_episode_count'].nil? ? 1 : p['total_episode_count']

					if Tmdb.crew_selected_departments.include?(job)
						persons_data << {movie_id: movie[:tmdb_id], person_id: p['id'], cast_crew: 'crew', job: job, order: nil, character: nil, total_episode_count: total_episode_count}
					end;			
				};

				stored_persons = MoviePerson.where(movie_id: movie[:tmdb_id])

				existing_keys = stored_persons.map do |person|
				  [person.movie_id, person.person_id, person.cast_crew, person.job]
				end.to_set

				new_persons_data = persons_data.reject do |person_hash|
				  key = [
				    person_hash[:movie_id],
				    person_hash[:person_id],
				    person_hash[:cast_crew],
				    person_hash[:job]
				  ]
				  existing_keys.include?(key)
				end

				if new_persons_data.any?
					MoviePerson.insert_all(new_persons_data)
				end

				if !data['seasons'].nil?
					seasons_data = data['seasons'].map{|s| {id: s['id'], movie_id: movie[:tmdb_id], season_number: s['season_number'], name: s['name'], 
									 air_date: ((Date.parse s['air_date']) rescue nil), episode_count: s['episode_count'], poster_path: s['poster_path'], vote_average: s['vote_average'] }}
					seasons_ids = seasons_data.map{ |p|p[:id]}
					existing_seasons_ids = Seasons.where(movie_id: movie[:tmdb_id]).pluck(:id)
				    missing_ids = seasons_ids - existing_seasons_ids
					missing_seasons_data = seasons_data.select { |g| missing_ids.include?(g[:id]) }
					if missing_seasons_data.any?
						Seasons.insert_all(missing_seasons_data)
					end		
				end

				puts "updated: #{title_de} #{title_de != original_title ? '(' + original_title + ')' : ''}"
				ret = true			
			end
		end
		ret
	end

	def self.reset_moviedata(id: nil)
		movie = Movie.find_by(id: id)
		if movie
			MoviePerson.destroy_by(movie_id: movie[:tmdb_id])
			rec = { tmdb_id: nil,
					imdb_id: nil,
					title_de: nil,
					original_title: nil,
					original_language: nil,
					overview: nil,
					poster_path: nil,
					backdrop_path: nil,
					media_type: nil,
					genre_ids: [],
					release_date: nil,
					homepage: nil,
					collectionid: nil,
					updated_at: DateTime.now
			}
			movie.update(rec)
			puts "reset: #{movie['title']}"
		end

		true
	end

	def self.delete_moviedata(id)
		movie = Movie.find_by(id: id)
		MoviePerson.destroy_by(movie_id: movie[:tmdb_id]) if movie
		Movie.destroy_by(id: id)			
	end

	def self.update_genre(genres)
		all_ids = genres.map{|g|g['id']}
		existing_ids = Genre.where(id: all_ids).pluck(:id)
		missing_ids = all_ids - existing_ids
		missing_genres_data = genres.select { |g| missing_ids.include?(g['id']) }
		genres_to_insert = missing_genres_data.map do |g|
  			{ id: g['id'], name: g['name'] }
		end
		if genres_to_insert.any?
			Genre.insert_all(genres_to_insert)
		end
		'done'
	end

	def self.update_collection(collection)
		collectiondb = Collection.find_by(id: collection['id'])
		if !collectiondb
			Collection.insert({id: collection['id'], name: collection['name'], poster_path: collection['poster_path']})
		end
		'done'
	end

	def self.updateall
		Movie.where.not(tmdb_id: nil).find_each do |movie|
			Tmdb.update_movie_with_tmdb(movieid: movie[:id], tmdb_id: movie[:tmdb_id])
		end
	end

	def self.get_imdb(command)
		base_url = "https://api.imdbapi.dev/#{command}"
		#query_string = URI.encode_www_form(params)
		uri = URI("#{base_url}")
	    http = Net::HTTP.new(uri.host, uri.port)
	    http.use_ssl = true
	    req =  Net::HTTP::Get.new(uri.request_uri)
	    req['Content-type']  = 'application/json'
	    req['Accept']        = 'application/json'
	    response = http.request(req)
		if response.is_a?(Net::HTTPSuccess)
 			data = JSON.parse(response.body)
 		else
 			data = nil
		end
		data
	end

	def self.update_imdb_data(tmdb_id)


		movie = Movie.find_by(tmdb_id: tmdb_id)

		if movie && !movie[:imdb_id].nil?
			data = Tmdb.get_imdb("titles/#{movie[:imdb_id]}")
			if !data.nil?
				movie.update(runtime: data['runtimeSeconds'], autoassign_skipped: false)
				persons = []
				['directors','writers','stars'].each do |team|
					if !data[team].nil?
						data[team].each do |p|
							persons << {id: p['id'],name: p['displayName'], imageurl: (p['primaryImage']['url'] rescue '')}
						end
					end
				end
				persons.uniq { |person| person[:id] }
				persons_ids = persons.map{ |p|p[:id] }
				existing_persons_ids = Person.where(id: persons_ids).pluck(:id)
				missing_ids = persons_ids - existing_persons_ids
				missing_persons_data = persons.select { |g| missing_ids.include?(g[:id]) }
				persons_to_insert = missing_persons_data.map do |g|
		  			{ id: g[:id], name: g[:name], imageurl: g[:imageurl] }
				end
				if persons_to_insert.any?
					Person.insert_all(persons_to_insert)
				end
				person_in_movie_ids =  PersonMovie.where(imdb_id: movie[:imdb_id]).pluck(:person_id)
				missing_persons_ids = persons_ids - person_in_movie_ids
				ids_to_insert = missing_persons_ids.map do |pid|
		  			{ person_id: pid, imdb_id: movie[:imdb_id] }
				end
				if ids_to_insert.any?
					PersonMovie.insert_all(ids_to_insert)
				end
			end
		end

	end

	def self.autoassign

		movie_to_process = Movie.where(imdb_id: nil, autoassign_skipped: false)

		movie_to_process.each do |movie|
			params = {
			  query: movie[:title],
			  include_adult: true,
			  language: 'de-DE',
			  page: 1
			}
			data = Tmdb.get(command: 'search/multi', params: params)
			if data['results'].count > 0
				rows = []
				result_filtered = data['results'].select { |r| (((Date.parse r['release_date']).strftime('%Y') rescue 0).to_i) == movie[:year].to_i }
				result_filtered.each do |m|
					title = m['title'].nil? ? m['name'] :  m['title']
					original_title = m['original_title'].nil? ? m['original_nam'] : m['original_title']
					rows <<[m['id'], title, original_title, ((Date.parse m['release_date']).strftime('%Y') rescue '')]
				end
				table = Terminal::Table.new :rows => rows
				if result_filtered.count == 1
				 	puts table
				 	puts "movieid: #{movie[:id]} | #{result_filtered.first["id"]}"
				 	Tmdb.update_movie_with_tmdb(movieid: movie[:id], tmdb_id: result_filtered.first["id"])
				else
					movie.update!(autoassign_skipped: true)
				end

			end
		end;

	end




end

