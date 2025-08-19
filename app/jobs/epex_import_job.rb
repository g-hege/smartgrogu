# app/jobs/epex_import_job.rb
class EpexImportJob < ApplicationJob
  queue_as :epex_importer
  def perform
  	EpexImporter.call
  	Rails.logger.info "Epex import Job done"
    GoodJob::Job.where(queue_name: 'epex_importer').where.not(finished_at: nil).delete_all
    GoodJob::Execution.where(queue_name: 'epex_importer').where.not(finished_at: nil).delete_all    
  end

end

