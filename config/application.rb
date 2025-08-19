require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module SmartGrogu
  class Application < Rails::Application
    # Load Rails defaults
    config.load_defaults 8.0

    # This tells Rails to serve error pages from the app itself, rather than using static error pages in public/
    config.exceptions_app = self.routes

    config.time_zone = "Vienna"

    config.active_record.default_timezone = :local
    
    config.active_job.queue_adapter = :good_job

    config.active_support.disable_all_core_ext = false
    
#    config.solcast = config_for(:smartgrogu)

  end
end
