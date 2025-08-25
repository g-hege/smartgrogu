# config valid for current version and patch releases of Capistrano
lock "~> 3.19.2"

set :application, "smartgrogu"
set :repo_url, 'git@github.com:g-hege/smartgrogu.git'

# Default branch is :master
ask :branch, `git rev-parse --abbrev-ref HEAD`.chomp

# Default deploy_to directory is /var/www/my_app_name
set :deploy_to, "/var/www/smartgrogu"

# Default value for :format is :airbrussh.
# set :format, :airbrussh

# You can configure the Airbrussh format using :format_options.
# These are the defaults.
# set :format_options, command_output: true, log_file: "log/capistrano.log", color: :auto, truncate: :auto

# Default value for :pty is false
# set :pty, true

set :linked_files, %w{config/database.yml config/secrets.yml config/master.key }

set :linked_dirs, %w{log tmp/pids tmp/cache tmp/sockets tmp/state vendor/bundle public/system public/uploads}


# Default value for :linked_files is []
# append :linked_files, "config/database.yml", 'config/master.key'

# Default value for linked_dirs is []
# append :linked_dirs, "log", "tmp/pids", "tmp/cache", "tmp/sockets", "public/system", "vendor", "storage"

# Default value for default_env is {}
# set :default_env, { path: "/opt/ruby/bin:$PATH" }

# Default value for local_user is ENV['USER']
# set :local_user, -> { `git config user.name`.chomp }

# Default value for keep_releases is 5
set :keep_releases, 5

# Uncomment the following to require manually verifying the host key before first deploy.
# set :ssh_options, verify_host_key: :secure

set :rvm_ruby_version, '3.3.5@smartgrogu' # Passe dies an deine Ruby-Version und Gemset an

namespace :deploy do

  task :restart do
    on roles(:app), in: :sequence, wait: 2 do
      sudo '/bin/systemctl restart puma.service'
      sudo '/bin/systemctl restart goodjob.service'
    end
  end

end
after 'deploy:publishing', 'deploy:restart'

