require 'sequel'
Sequel.extension :migration

Sequel.migration do
  change do
    create_table(:repos) do
      primary_key :id
      String :name
      String :target
      String :watch_label
      String :channels
    end
  end
end
