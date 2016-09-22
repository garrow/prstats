require 'sequel'

class Repo < Sequel::Model
  set_allowed_columns :target, :watch_label
end
