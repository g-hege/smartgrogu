# app/api/v1/daily_runtime.rb
module API
  module V1
    class EventMonitor < Grape::API
      version 'v1', using: :path
      format :json
      prefix :api

      resource :event_monitor do
        desc 'Creates a new entry in event_monitor'
        params do
          requires :device_id, type: String, desc: 'The unique ID of the Shelly device'
          requires :event_stamp, type: DateTime, desc: 'event timestamp'
          requires :event, type: String, desc: 'Event eg Open'
          optional :info, type: String, desc: 'Additional info'
        end

        post do
          shelly_config = Rails.application.credentials.shelly.device.find { |_key, value| value[:id] == params[:device_id] }

          if shelly_config.present?
            device_name = shelly_config.first.to_s

            record = ::EventMonitor.new(
              event_stamp: params[:event_stamp],
              event: params[:event],
              device: device_name,
              info: params[:info]
            )

            if record.save
              Rails.logger.info "#{params[:device_id]} - #{params[:event_stamp]} | #{device_name} -> #{params[:event]}"
              status 201
              { status: 'success', message: 'data saved' }
            else
              Rails.logger.error "API Post::EventMonitor - Validation failed: #{record.errors.full_messages.join(', ')}"
              error!({ error: 'Validation failed', details: record.errors.full_messages }, 422)
            end
          else
            Rails.logger.error "API Post::EventMonitor - device: #{params[:device_id]} not configured!"
            error!({ error: 'Device not configured' }, 404)
          end
        end
      end
    end
  end
end