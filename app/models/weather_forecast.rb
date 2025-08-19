class WeatherForecast < ApplicationRecord
	self.table_name = 'weather_forecast'

	def self.import 
   		WeatherImporter.call
  	end

end
