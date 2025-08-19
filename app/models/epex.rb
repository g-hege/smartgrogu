class Epex < ApplicationRecord
	  self.table_name = "epex"
  def self.timestamps
    false
  end

  def self.current_price
    current_time = Time.zone.now
    response = self.where("timestamp <= ?", current_time).order(timestamp: :desc).first
    if response
      (response.marketprice/10).to_f
    else
      nil
    end
  end

  def self.import 
    EpexImporter.call
  end

end
