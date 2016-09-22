require 'sequel'

class Repo < Sequel::Model
  plugin :validation_helpers

  set_allowed_columns :target, :watch_label, :name, :channels

  def validate
    super
    validates_presence :target
  end


  def self.for_channel(channel_name)
    first(channels: channel_name)
  end
end
