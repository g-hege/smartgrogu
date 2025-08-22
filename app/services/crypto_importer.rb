# app/service/crypto_importer.rb

class CryptoImporter
  def self.call
    new.call
  end

  def call
    data = fetch_data
    parse_and_save_cypto_data(data) if data
  end

  private

  def fetch_data

    uri = URI.parse("#{Rails.application.credentials.coinmarketcap.url}/v1/cryptocurrency/listings/latest")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == 'https')
    params = {'start' => 1,'limit' => 500, 'convert' => 'EUR'}
    uri.query = URI.encode_www_form(params)
    
    request = Net::HTTP::Get.new(uri.request_uri)
    request['Accept'] = 'application/json'
    
    if DateTime.now.hour % 2 == 0
      request['X-CMC_PRO_API_KEY'] = Rails.application.credentials.coinmarketcap.auth_key
    else
      request['X-CMC_PRO_API_KEY'] = Rails.application.credentials.coinmarketcap.auth_key_2
    end


    response = http.request(request)
    
    return JSON.parse(response.body) if response.is_a?(Net::HTTPSuccess)
    nil
  rescue StandardError => e
    Rails.logger.error "Fehler beim Abrufen der Cyrpto Daten: #{e.message}"
    nil
  end

  def parse_and_save_cypto_data(body)
    Rails.application.credentials.coinmarketcap.watch_currencies.each do |currencie|
      c = body['data'].find{|c| c['slug'] == currencie}
      if !c.nil?
        rec = {name: c['name'], symbol: c['symbol'], 
            slug: c['slug'], last_updated: c['last_updated'],
            price: c['quote']['EUR']['price']}
        Crypto.create(rec)
      end
    end
    Crypto.where('last_updated < ?', 7.days.ago).delete_all
  end



end