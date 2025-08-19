# app/jobs/weather_import_job.rb
class MqttStartListenerJob < ApplicationJob
  queue_as :mqtt_start_listener
  
  def perform

    Rails.logger.info "START MqttStartListenerJob *******************************"

    GoodJob::Job.where(queue_name: 'mqtt_listener').where.not(finished_at: nil).delete_all
    GoodJob::Execution.where(queue_name: 'mqtt_listener').where.not(finished_at: nil).delete_all

    if GoodJob::Job.where(queue_name: 'mqtt_listener', finished_at: nil).count == 0
      MqttListenerJob.perform_later
    end

    GoodJob::Job.where(queue_name: 'mqtt_start_listener').where.not(finished_at: nil).delete_all
    GoodJob::Execution.where(queue_name: 'mqtt_start_listener').where.not(finished_at: nil).delete_all
    
    Rails.logger.info "END MqttStartListenerJob *******************************"
  end

end

