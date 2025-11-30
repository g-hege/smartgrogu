Rails.application.config.after_initialize do
  if defined?(GoodJob) && (Rails.env.development? || Rails.env.production?)
    begin
      unless GoodJob::Job.where(job_class: PermanentMonitorJob.name).exists?
        PermanentMonitorJob.perform_later 
        Rails.logger.info "PermanentMonitorJob wurde erfolgreich beim App-Start gestartet."
      end
    rescue ActiveRecord::StatementInvalid => e
      Rails.logger.warn "PermanentMonitorJob konnte nicht gestartet werden, da die Datenbanktabellen nicht bereit sind: #{e.message}"
    end
  end
end