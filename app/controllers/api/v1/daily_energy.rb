# app/api/v1/daily_energy.rb
module API
  module V1
    class DailyEnergy < Grape::API
      version 'v1', using: :path
      format :json
      prefix :api

      resource :daily_energy do
        desc 'Creates or Update a new daily energy consumption record'
        params do
          requires :day, type: Date, desc: 'Date of the measurement'
          requires :grid_consumed, type: Float, desc: 'from Grid in kWh'
          requires :solar_self_consumed, type: Float, desc: 'Solar self consumed in kWh'
          requires :solar_to_grid, type: Float, desc: 'Solar to grid in kWh'
          requires :autarky_rate, type: Float, desc: 'autarky rate in percent'
          requires :self_consumed_rate, type: Float, desc: 'self consumed_rate in percent'                                        
        end

        post do
            record = ::Energy.find_or_initialize_by(day: params[:day])
            record.day = params[:day]
            record.grid_consumed = params[:grid_consumed]
            record.solar_self_consumed = params[:solar_self_consumed]
            record.solar_to_grid = params[:solar_to_grid]
            record.autarky_rate = params[:autarky_rate]
            record.self_consumed_rate = params[:self_consumed_rate]            
            record.save

          Rails.logger.info "API Post::DailyEnergy"
          { status: 'success!!', message: 'data saved' }

        end
      end
    end
  end
end