require 'sequel'

class Stats < Sequel::Model
  set_allowed_columns :repo_id, :source_data, :calculated, :config, :trigger_type, :trigger_id


  def self.history(repo)
    # DB["select id, calculated->'open' as open_prs, calculated->'needy' as needy from stats where repo_id = #{repo.id}"]
    DB["select id, calculated->'open' as open_prs, calculated->'needy' as needy from stats"]
  end
end


