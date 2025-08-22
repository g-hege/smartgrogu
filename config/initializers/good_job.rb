# config/initializers/good_job.rb
Rails.application.configure do

	# Aktiviert den Bereinigungs-Worker
	config.good_job.enable_purge = true

	config.good_job.enable_cron = true

	# Konfiguriert die Löschregeln für erfolgreich abgeschlossene Jobs
	config.good_job.successful_executions_retention_period = 1.days

	# Konfiguriert die Löschregeln für fehlgeschlagene Jobs
	config.good_job.discarded_executions_retention_period = 14.days
	# ... deine anderen GoodJob-Konfigurationen ...

	Rails.application.configure do
	  config.good_job.cron = {
	    mqtt_start_listener: {
	      cron: '*/1 * * * *', # each minute
	      class: 'MqttStartListenerJob',
	      description: 'start mqtt listener job'
	    },	  	
	    epex_import: {
	      cron: '1 * * * *', # 1 Minute nach Punkt
	      class: 'EpexImportJob',
	      description: 'import new epex spot (European Power Exchange) prices'
	    },
	    spotty_import: {
	      cron: '30 * * * *', # jede stunde um :30
	      class: 'SpottyImportJob',
	      description: 'import spotty consumption data'
	    },
	    solcast_import: {
	      cron: '2 * * * *', # 2 Minute nach Punkt
	      class: 'SolcastImportJob',
	      description: 'import solar data forecasts'
	    },
	    weather_import: {
	      cron: '*/10 * * * *', # alle 10 Minuten
	      class: 'WeatherImportJob',
	      description: 'import  weather forecasts'
	    },
	    twilight_import: {
	      cron: '1 0 * * *', # one minute after midnight
	      class: 'TwilightImportJob',
	      description: 'import twilight data for today'
	    },
	    crypto_import: {
	      cron: '10 0 * * *', # 
	      class: 'CryptoImportJob',
	      description: 'import actual crypto data'
	    }
	  }
	end

	if ENV['GOOD_JOB_WORKER'] == 'true'
		Rails.application.config.after_initialize do
			unless GoodJob::Job.where(job_class: 'MqttPublisherJob', finished_at: nil).exists?
		    	Rails.logger.info "Starting MqttPublisherJob chain..."
		    	MqttPublisherJob.perform_later
			end
	    	GoodJob::Job.where(queue_name: 'mqtt_listener').delete_all
	    	GoodJob::Execution.where(queue_name: 'mqtt_listener').delete_all
		end



	end



end