# config/puma.rb
workers Integer(ENV.fetch("WEB_CONCURRENCY", 2)) # Anzahl der Worker-Prozesse
threads_count = Integer(ENV.fetch("RAILS_MAX_THREADS", 5)) # Anzahl der Threads pro Worker
threads threads_count, threads_count

# Bindet an eine IP-Adresse und einen Port
port ENV.fetch("PORT") { 3000 }
environment ENV.fetch("RAILS_ENV") { "development" }

# Fügt dem Pfad alle Plugins und gems hinzu, die für diese App benötigt werden
# Rails 7 oder höher. Für ältere Versionen verwenden Sie "require 'bundler/setup'"

if ENV.fetch("RAILS_ENV", "development") == "development"
  plugin :tmp_restart
end

preload_app!