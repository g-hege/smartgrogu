module API
  module V1
    class Base < Grape::API

      before do
#        Rails.logger.info "Received Headers: #{request.headers.to_h.inspect}"
         error!('401 Unauthorized!!', 401) unless headers['x-api-key'] == '12345'
      end

      mount API::V1::DailyRuntime
      mount API::V1::DailyEnergy

    end
  end
end
