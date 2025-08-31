class UpdateEnergie

	def self.run

		startdate = Consumption.minimum(:timestamp).to_date
		enddate = Energy.minimum(:day) - 1.day

# enddate 04 Mar 2024

		(startdate..enddate).each do |calc_day|
			sums = Consumption.where(device: 'wienstrom').where("DATE(timestamp) = ?", calc_day)
			real_wiener_netze = sums.sum(:value)/1000
			price_netto = 0
		
			solar_sums = Consumption.where(device: 'solar').where("DATE(timestamp) = ?", calc_day)
			solar_self_consumed = solar_sums.sum(:value)

			rec = {
				day: calc_day,
				grid_consumed: real_wiener_netze,
				solar_self_consumed: solar_self_consumed/1000,
				solar_to_grid: 0,
				autarky_rate:  0,
				self_consumed_rate: 0,
				real_wiener_netze: real_wiener_netze,
				grid_price_netto: price_netto / 100

			}


			e = Energy.find_or_initialize_by(day: rec[:day])
			e.update(rec)
		end


	end


end


