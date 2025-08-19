# app/jobs/application_job.rb
class ApplicationJob < ActiveJob::Base
  # Hier können Sie globale Einstellungen für alle Jobs definieren,
  # wie z.B. die Warteschlange, an die sie gesendet werden sollen.
  queue_as :default
end