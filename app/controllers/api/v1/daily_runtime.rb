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
          requires :device_id, type: String, desc: 'The unique ID of the Shelly device'
          requires :day, type: Date, desc: 'Date of the measurement'
          requires :runtime, type: Float, desc: 'Runtime in secounds'
        end

        post do

          shelly_config = Rails.application.credentials.shelly.device.find { |key, value| value[:id] == params[:device_id] }
          if !shelly_config.nil?
            device = shelly_config.first.to_s
            record = ::DailyRuntime.find_or_initialize_by(device_id: params[:device_id], day: params[:day])
            record.day = params[:day]
            record.device_id = params[:device_id]
            record.device = device
            record.runtime = params[:runtime]
            record.save
          end

          Rails.logger.info "API Post::DailyRuntime"
          { status: 'success!!', message: 'data saved' }

        end
      end
    end
  end
end