# app/jobs/weather_import_job.rb
class ShellyImportJob < ApplicationJob
  queue_as :shelly_importer

  def perform
  	ShellyCloud.import
  	Rails.logger.info "Shelly import done"
    GoodJob::Job.where(queue_name: 'shelly_importer').where.not(finished_at: nil).delete_all
    GoodJob::Execution.where(queue_name: 'shelly_importer').where.not(finished_at: nil).delete_all
  end

end

