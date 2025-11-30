class ElasticsearchMovieIndexer

	def self.init

		if ES_CLIENT.indices.exists? index:  Rails.configuration.index_movie
			puts "delete index: #{ Rails.configuration.index_movie}"
   			ES_CLIENT.indices.delete index:  Rails.configuration.index_movie
		end

	  	ES_CLIENT.indices.create index: Rails.configuration.index_movie, body: movie_body
	
		@bulkdata = []

	  	Movie.limit(10000).each do |movie|
	  		puts movie.title_de
			@bulkdata << { index:  { _index: Rails.configuration.index_movie, _id: movie.id, data: MovieDecorator.new(movie).as_json('x')}}
			bulkwrite if @bulkdata.count >= 50
	  	end
		bulkwrite

	end

	def self.bulkwrite
		return if @bulkdata.count == 0
		@bulktotal = @bulkdata.count
		puts "bulkwrite ======> #{@bulkdata.count} Records | total: #{@bulktotal} Records"
		r = ES_CLIENT.bulk  body: @bulkdata 
		if r['errors']
			puts r
		end
		@bulkdata = []
	end


	def self.update_index
		@bulkdata = []
		Movie.where(sync_now: true).find_each do |movie|
			@bulkdata << { index:  { _index: Rails.configuration.index_movie, _id: movie.id, data:  MovieDecorator.new(movie).as_json('x')}}
			bulkwrite if @bulkdata.count >= 50
			movie.update_columns(sync_now: false)
		end

		bulkwrite

		DeletedKeys.where(table_name: 'movie', sync_now: true).find_each do |deleted_movie|

			begin
				ES_CLIENT.delete index: Rails.configuration.index_movie, id:  deleted_movie.identifier
			rescue Elasticsearch::Transport::Transport::Errors::NotFound
			    Rails.logger.warn "ES delete: Document ID #{deleted_movie.identifier} not found. Proceeding."
			rescue => e
			    Rails.logger.error "ES delete error for ID #{deleted_movie.identifier}: #{e.message}"
			    next 
			end

			deleted_movie.update_columns(sync_now: false)
		end

	end


	def self.movie_body
	{
		settings: {
			analysis: {
				analyzer: {
					folding: {
						tokenizer: 'standard',
						filter: ['lowercase','asciifolding']
					}
				}
			}
		},
		mappings: {
	        properties: {
	            title:	  {type: "text", analyzer: "folding", fields:{ keyword: { type: "keyword", ignore_above: 256 }}},
	            keywords: {type: "text", analyzer: "folding", fields: { raw: { type: "keyword"}}},
				movie_id: {type: "text", fields: { keyword: {type: "keyword", ignore_above: 256}}},
				imdb_id:  {type: "text", fields: { keyword: {type: "keyword", ignore_above: 256}}}			
        	}
	    }
	}
	end



end