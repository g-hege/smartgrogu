# app/jobs/weather_import_job.rb
class TwilightImportJob < ApplicationJob
  queue_as :twilight_importer
  def perform
  	TwilightImporter.call
  	Rails.logger.info "import Twilight for today: done"
    GoodJob::Job.where(queue_name: 'twilight_importer').where.not(finished_at: nil).delete_all
    GoodJob::Execution.where(queue_name: 'twilight_importer').where.not(finished_at: nil).delete_all

  end

end

