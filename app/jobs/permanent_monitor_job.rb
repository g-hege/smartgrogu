class PermanentMonitorJob < ApplicationJob

  # PermanentMonitorJob.perform_later

  queue_as :default

  CYCLE_INTERVAL = 5.seconds 

  def perform

    ElasticsearchMovieIndexer.update_index

    self.class.set(wait: CYCLE_INTERVAL).perform_later
  end
end