require "test_helper"
require Rails.root.join("db/migrate/20261017130000_restore_grind_suggestion_columns")

class RestoreGrindSuggestionColumnsTest < ActiveSupport::TestCase
  test "retains existing grind suggestion data when rerun" do
    user = create(:user, :admin, :with_coffee_management)
    bag = create(:coffee_bag, roaster: create(:roaster, user:), grind_suggestion: [{"profile" => "Adaptive"}])
    shot = create(:shot, user:, grind_suggestion: {"label" => "Finer"})

    RestoreGrindSuggestionColumns.new.migrate(:up)
    RestoreGrindSuggestionColumns.new.migrate(:up)

    assert_equal [{"profile" => "Adaptive"}], bag.reload.grind_suggestion
    assert_equal({"label" => "Finer"}, shot.reload.grind_suggestion)
  end

  test "restores missing columns without removing unrelated data" do
    user = create(:user, :admin, :with_coffee_management)
    bag = create(:coffee_bag, roaster: create(:roaster, user:))
    shot = create(:shot, user:, grinder_setting: "13")
    connection = ActiveRecord::Base.connection

    connection.remove_column(:shots, :grind_suggestion)
    connection.remove_column(:coffee_bags, :grind_suggestion)
    Shot.reset_column_information
    CoffeeBag.reset_column_information

    RestoreGrindSuggestionColumns.new.migrate(:up)
    Shot.reset_column_information
    CoffeeBag.reset_column_information

    assert connection.column_exists?(:shots, :grind_suggestion)
    assert connection.column_exists?(:coffee_bags, :grind_suggestion)
    assert_equal "13", shot.reload.grinder_setting
    assert_nil bag.reload.grind_suggestion
  ensure
    RestoreGrindSuggestionColumns.new.migrate(:up)
    Shot.reset_column_information
    CoffeeBag.reset_column_information
  end
end
