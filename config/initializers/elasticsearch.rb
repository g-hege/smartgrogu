# config/initializers/elasticsearch.rb

es_config = Rails.application.credentials.elasticsearch.to_h

ES_CLIENT = Elasticsearch::Client.new Hashie.symbolize_keys(es_config)
Elasticsearch::Model.client = ES_CLIENT

begin
  ES_CLIENT.cluster.health
  Rails.logger.info "Elasticsearch-Client erfolgreich initialisiert."
rescue StandardError => e
  Rails.logger.error "FEHLER beim Initialisieren des Elasticsearch-Clients: #{e.message}"
end
