# app/jobs/crypto_import_job.rb
class CryptoImportJob < ApplicationJob
  queue_as :crypto_importer
  def perform
  	CryptoImporter.call
  	Rails.logger.info "Crypto import done"
    GoodJob::Job.where(queue_name: 'crypto_importer').where.not(finished_at: nil).delete_all
    GoodJob::Execution.where(queue_name: 'crypto_importer').where.not(finished_at: nil).delete_all
  end

end

