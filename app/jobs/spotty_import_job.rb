# app/jobs/spotty_import_job.rb
class SpottyImportJob < ApplicationJob
  queue_as :spotty_importer
  def perform
  	SpottyImporter.call
  	Rails.logger.info "Spotty import done"
    GoodJob::Job.where(queue_name: 'spotty_importer').where.not(finished_at: nil).delete_all
    GoodJob::Execution.where(queue_name: 'spotty_importer').where.not(finished_at: nil).delete_all
  end

end

