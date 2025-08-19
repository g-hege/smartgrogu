# app/jobs/weather_import_job.rb
class WeatherImportJob < ApplicationJob
  queue_as :weather_importer

  def perform
  	WeatherImporter.call
  	Rails.logger.info "Open Weather import done"
    GoodJob::Job.where(queue_name: 'weather_importer').where.not(finished_at: nil).delete_all
    GoodJob::Execution.where(queue_name: 'weather_importer').where.not(finished_at: nil).delete_all
  end

end

