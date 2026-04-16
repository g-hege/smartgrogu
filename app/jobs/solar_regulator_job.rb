# app/jobs/weather_import_job.rb
class SolarRegulatorJob < ApplicationJob
  queue_as :solar_regulator

  def perform
  	SolarRegulator.call
    GoodJob::Job.where(queue_name: 'solar_regulator').where.not(finished_at: nil).delete_all
    GoodJob::Execution.where(queue_name: 'solar_regulator').where.not(finished_at: nil).delete_all
  end

end

