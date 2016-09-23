require 'sequel'
Sequel.extension :migration

Sequel.migration do
  change do
    create_table(:stats) do
      primary_key :id
      Integer :repo_id
      JSON :source_data
      JSON :calculated
      String :config
      String :trigger_type
      String :trigger_name
    end
  end
end
