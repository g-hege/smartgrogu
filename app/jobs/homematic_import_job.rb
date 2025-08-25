# app/jobs/homematic_import_job.rb
class HomematicImportJob < ApplicationJob
  queue_as :homematic_importer
  def perform
  	HomematicImporter.import_actual_data
  	Rails.logger.info "Homematic import done"
    GoodJob::Job.where(queue_name: 'homematic_importer').where.not(finished_at: nil).delete_all
    GoodJob::Execution.where(queue_name: 'homematic_importer').where.not(finished_at: nil).delete_all
  end

end

