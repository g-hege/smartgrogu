module API
  module V1
    class Base < Grape::API

      before do
         Rails.logger.info "Received Headers: #{request.headers.to_h.inspect}"
         Rails.logger.info "Params: #{params.inspect}"
         error!('401 Unauthorized!!', 401) unless Rails.application.credentials.apikey].include?(headers['x-api-key'])
      end

      mount API::V1::DailyRuntime
      mount API::V1::DailyEnergy

    end
  end
end
