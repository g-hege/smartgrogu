# config/initializers/shelly_setup.rb

unless ENV['GOOD_JOB_WORKER'] == 'true'
  Rails.application.config.after_initialize do
    Rails.logger.info 'Initialisiere Shelly KVS-Daten...'
    begin
      Shelly.init_kvs
    rescue StandardError => e
      Rails.logger.error "Fehler beim Initialisieren der Shelly KVS-Daten: #{e.message}"
    end
  end
end