require 'dotenv'
require 'sequel'

Dotenv.load

DB = Sequel.connect(ENV.fetch('DATABASE_URL'))

require_relative 'models/repo'
require_relative 'models/stats'
