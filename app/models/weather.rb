class Weather < ApplicationRecord
	self.table_name = 'weather' 

  def self.import 
    WeatherImporter.call
  end

end
