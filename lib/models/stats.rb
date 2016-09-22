require 'sequel'

class Stats < Sequel::Model
  set_allowed_columns :repo_id, :source_data, :calculated, :config, :trigger_type, :trigger_id
end


