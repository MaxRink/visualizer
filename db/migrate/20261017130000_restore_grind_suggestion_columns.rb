class RestoreGrindSuggestionColumns < ActiveRecord::Migration[8.1]
  def up
    add_column :shots, :grind_suggestion, :jsonb unless column_exists?(:shots, :grind_suggestion)
    add_column :coffee_bags, :grind_suggestion, :jsonb unless column_exists?(:coffee_bags, :grind_suggestion)
  end
end
