# app/services/epex_importer.rb

class EpexImporter
  def self.call()
    new().call
  end

  def initialize()

  end

  def call
    date_from = Epex.maximum(:timestamp).to_date.prev_day # rescue Date.parse(Hegesmart.config.wstw.startdate)
    date_to = date_from.next_month
    uri = URI.parse("https://api.awattar.at/v1/marketdata?start=#{date_from.to_time.to_i}000&end=#{date_to.to_time.to_i}000")
    response = Net::HTTP.get_response(uri)
    puts "datefrom: #{date_from} to #{date_to}"

    if response.code.to_i == 200
      data = JSON response.body
      puts "#{data['data'].count} Records imported from awattar"

      Epex.where('timestamp >= ?', date_from).delete_all
      insertrecs = data['data'].map { |h| { timestamp: Time.at(h['start_timestamp'].to_s[0..-4].to_i).to_datetime.utc, marketprice:  h['marketprice']}}
      Epex.insert_all(insertrecs)
    end

  end

end