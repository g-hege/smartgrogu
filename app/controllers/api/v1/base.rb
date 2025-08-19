module API
  module V1
    class Base < Grape::API

      before do
        error!('401 Unauthorized', 401) unless headers['X-Api-Key'] == '12345'
      end

      mount API::V1::DailyRuntime

    end
  end
end