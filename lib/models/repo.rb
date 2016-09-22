require 'sequel'

class Repo < Sequel::Model
  plugin :validation_helpers

  set_allowed_columns :target, :watch_label, :name, :channels

  def validate
    super
    validates_presence :target
  end
end
