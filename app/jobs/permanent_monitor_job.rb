class PermanentMonitorJob < ApplicationJob

  # PermanentMonitorJob.perform_later

  queue_as :permanent_monitor_job

  CYCLE_INTERVAL = 5.seconds 

  def perform

    ElasticsearchMovieIndexer.update_index

    GoodJob::Job.where(job_class: PermanentMonitorJob.name).where.not(finished_at: nil).delete_all
    
    self.class.set(wait: CYCLE_INTERVAL).perform_later
  end
end