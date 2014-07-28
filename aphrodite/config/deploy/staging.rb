server "107.170.13.39", :web, :app, :db, primary: true
set :branch, "staging"
set :user, "deploy"

namespace :deploy do
  desc "Make sure local git is in sync with remote."
  task :check_revision, roles: :web do
    unless `git rev-parse HEAD` == `git rev-parse origin/staging`
      puts "WARNING: HEAD is not the same as origin/staging"
      puts "Run `git push` to sync changes."
      exit
    end
  end
end
