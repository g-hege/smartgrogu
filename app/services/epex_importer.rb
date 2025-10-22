# app/services/epex_importer.rb

class EpexImporter
  def self.call()
    new().call
  end

  def self.send_current_epex()
    new().send_current_epex
  end
  

  def initialize()

  end

  def call

    uri = URI.parse("https://i.spottyenergie.at/api/prices/MARKET/4aae2e61-00df-462e-9f48-a9a96fafa45d?timezone=at")
#    uri = URI.parse("https://i.spottyenergie.at/api/prices/CONSUMPTION/4aae2e61-00df-462e-9f48-a9a96fafa45d?timezone=at")

    response = Net::HTTP.get_response(uri)
 
    if response.code.to_i == 200
 
      data = JSON response.body
      puts "#{data.count} epex price items imported from spotty"
      Epex.where('timestamp >= ?', data.first['from']).delete_all
      insertrecs = data.map { |h| { timestamp: DateTime.strptime(h['from']) , marketprice:  h['price'], netto: (h['price'] + 1.894) * 1.2}}
      Epex.insert_all(insertrecs)
    end
    
  end

  def send_current_epex

        ShellyCloud.update_market_price

        current_price = Epex.where('timestamp < ?', Time.now)
                        .order(timestamp: :desc)
                        .limit(1)
                        .pluck(:marketprice)
                        .first.to_f #   cent/kWh

        Shelly.set_kvs('poolcontrol','CurrentMarketPrice',current_price.round(1))

  end



end