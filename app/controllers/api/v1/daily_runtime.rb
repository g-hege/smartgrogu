# app/api/v1/daily_runtime.rb
module API
  module V1
    class DailyRuntime < Grape::API
      version 'v1', using: :path
      format :json
      prefix :api

      resource :daily_runtime do
        desc 'Creates a new daily consumption record for a Shelly device'
        params do
          requires :device, type: String, desc: 'The unique ID of the Shelly device'
          requires :day, type: Date, desc: 'Date of the measurement'
          requires :value, type: Float, desc: 'Runtime in secounds'
        end

        post do
          # Hier wird die Logik zum Speichern in der Datenbank ausgeführt
  #        DailyRuntime.create!(
  #          device_id: params[:device_id],
  #          date: params[:day],
  #          value: params[:value]
  #        )
          Rails.logger.info "API Post::DailyRuntime"
          { status: 'success!!', message: 'data saved' }
        end
      end
    end
  end
end