# app/jobs/solcast_import_job.rb
class SolcastImportJob < ApplicationJob
  queue_as :solcast_importer
  def perform
  	SolcastImporter.call
  	Rails.logger.info "Solarcast import done"
    GoodJob::Job.where(queue_name: 'solcast_importer').where.not(finished_at: nil).delete_all
    GoodJob::Execution.where(queue_name: 'solcast_importer').where.not(finished_at: nil).delete_all
  end

end

