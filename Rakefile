require 'logger'

namespace :db do
  desc "Run migrations"
  task :migrate, [:version] do |t, args|
    require_relative './lib/boot'

    Sequel.extension :migration
    # Boot sets DB global const.
    # db = Sequel.connect(ENV.fetch("DATABASE_URL"))
    DB.logger = Logger.new($stdout)

    if args[:version]
      puts "Migrating to version #{args[:version]}"
      Sequel::Migrator.run(DB, "db/migrations", target: args[:version].to_i)
    else
      puts "Migrating to latest"
      Sequel::Migrator.run(DB, "db/migrations")
    end
  end
end
