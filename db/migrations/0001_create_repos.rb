require 'sequel'
# DB.drop_table(:repos)

DB.create_table(:repos) do
  primary_key :id
  String :target
  String :watch_label
end

# Repo.create(target: 'locomote/cbt', watch_label: 'Review me')
