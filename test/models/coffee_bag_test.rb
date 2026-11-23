require "test_helper"

class CoffeeBagTest < ActiveSupport::TestCase
  attr_reader :user, :roaster

  setup do
    @user = FactoryBot.create(:user, :with_coffee_management, email: "coffee-bag-#{name.parameterize}@example.com")
    @roaster = FactoryBot.create(:roaster, user:)
  end

  test "full display name puts coffee first with date and archive in one annotation" do
    bag = build(:coffee_bag, name: "Bourbon", roaster: build(:roaster, name: "Roaster"), roast_date: Date.new(2026, 1, 12), archived_at: Time.current)
    assert_equal "Bourbon - Roaster (January 12, 2026, Archived)", bag.full_display_name
    bag.roast_date = nil
    assert_equal "Bourbon - Roaster (Archived)", bag.full_display_name
    bag.archived_at = nil
    assert_equal "Bourbon - Roaster", bag.full_display_name
  end

  test ".for_roaster_by_name_and_date creates a new CoffeeBag if one does not exist" do
    shot = FactoryBot.build_stubbed(:shot, user:, bean_type: "Ethiopian", roast_date: "2023-10-01", roast_level: "Medium")

    assert_difference "CoffeeBag.count", 1 do
      CoffeeBag.for_roaster_by_name_and_date(roaster, shot.bean_type, shot.roast_date, roast_level: shot.roast_level)
    end

    coffee_bag = CoffeeBag.last
    assert_equal "Ethiopian", coffee_bag.name
    assert_equal Date.parse("2023-10-01"), coffee_bag.roast_date
    assert_equal "Medium", coffee_bag.roast_level
    assert_equal roaster.id, coffee_bag.roaster_id
  end

  test ".for_roaster_by_name_and_date finds an existing CoffeeBag if one exists" do
    roast_date = "2023-10-01".to_date
    coffee_bag = roaster.coffee_bags.create(name: "Ethiopian", roast_date:, roast_level: "Medium")

    shot = FactoryBot.build_stubbed(:shot, user:, bean_type: "Ethiopian", roast_date: "2023-10-01", roast_level: "Medium")

    assert_no_difference "CoffeeBag.count" do
      found_bag = CoffeeBag.for_roaster_by_name_and_date(roaster, shot.bean_type, shot.roast_date, roast_level: shot.roast_level)
      assert_equal coffee_bag, found_bag
    end
  end

  test ".for_roaster_by_name_and_date finds an existing CoffeeBag if one exists case insensitive" do
    roast_date = "2023-10-01".to_date
    coffee_bag = roaster.coffee_bags.create(name: "Ethiopian", roast_date:, roast_level: "Medium")

    shot = FactoryBot.build_stubbed(:shot, user:, bean_type: "eThIoPiAN", roast_date: "2023-10-01", roast_level: "Medium")

    assert_no_difference "CoffeeBag.count" do
      found_bag = CoffeeBag.for_roaster_by_name_and_date(roaster, shot.bean_type, shot.roast_date, roast_level: shot.roast_level)
      assert_equal coffee_bag, found_bag
    end
  end

  test ".for_roaster_by_name_and_date handles invalid roast_date in shot" do
    shot = FactoryBot.build_stubbed(:shot, user:, bean_type: "Ethiopian", roast_date: "invalid-date", roast_level: "Medium")

    assert_difference "CoffeeBag.count", 1 do
      CoffeeBag.for_roaster_by_name_and_date(roaster, shot.bean_type, shot.roast_date, roast_level: shot.roast_level)
    end

    coffee_bag = CoffeeBag.last
    assert_equal "Ethiopian", coffee_bag.name
    assert_nil coffee_bag.roast_date
    assert_equal "Medium", coffee_bag.roast_level
    assert_equal roaster.id, coffee_bag.roaster_id
  end

  test "frozen? is true only when frozen date exists and defrosted date is blank" do
    coffee_bag = create(:coffee_bag, roaster:, frozen_date: Date.new(2025, 1, 10), defrosted_date: nil)
    assert coffee_bag.frozen?

    coffee_bag.update!(defrosted_date: Date.new(2025, 1, 15))
    assert_not coffee_bag.frozen?
  end

  test "days_in_freezer returns nil when never frozen" do
    coffee_bag = create(:coffee_bag, roaster:, frozen_date: nil, defrosted_date: nil)

    assert_nil coffee_bag.days_in_freezer(up_to: Date.new(2025, 1, 9))
  end

  test "days_in_freezer returns nil when shot date is before frozen date" do
    coffee_bag = create(:coffee_bag, roaster:, frozen_date: Date.new(2025, 1, 10), defrosted_date: nil)

    assert_nil coffee_bag.days_in_freezer(up_to: Date.new(2025, 1, 9))
  end

  test "days_in_freezer uses shot date when bag is still frozen" do
    coffee_bag = create(:coffee_bag, roaster:, frozen_date: Date.new(2025, 1, 10), defrosted_date: nil)

    assert_equal 5, coffee_bag.days_in_freezer(up_to: Date.new(2025, 1, 15))
  end

  test "days_in_freezer uses defrosted date when it is before shot date" do
    coffee_bag = create(:coffee_bag, roaster:, frozen_date: Date.new(2025, 1, 10), defrosted_date: Date.new(2025, 1, 12))

    assert_equal 2, coffee_bag.days_in_freezer(up_to: Date.new(2025, 1, 15))
  end

  test "defrosted date must be after frozen date" do
    coffee_bag = build(:coffee_bag, roaster:, roast_date: Date.new(2025, 1, 1), frozen_date: Date.new(2025, 1, 10), defrosted_date: Date.new(2025, 1, 9))

    assert_not coffee_bag.valid?
    assert_includes coffee_bag.errors[:defrosted_date], "must be after frozen date"
  end

  test "defrosted date requires frozen date" do
    coffee_bag = build(:coffee_bag, roaster:, roast_date: Date.new(2025, 1, 1), frozen_date: nil, defrosted_date: Date.new(2025, 1, 9))

    assert_not coffee_bag.valid?
    assert_includes coffee_bag.errors[:defrosted_date], "requires a frozen date"
  end

  test "by_brewability orders active, then frozen, then archived" do
    active = create(:coffee_bag, roaster:, name: "Active", roast_date: Date.new(2024, 1, 1), frozen_date: nil, defrosted_date: nil, archived_at: nil)
    frozen = create(:coffee_bag, roaster:, name: "Frozen", roast_date: Date.new(2024, 2, 1), frozen_date: Date.new(2024, 2, 5), defrosted_date: nil, archived_at: nil)
    archived = create(:coffee_bag, roaster:, name: "Archived", roast_date: Date.new(2024, 3, 1), frozen_date: nil, defrosted_date: nil, archived_at: Time.current)

    assert_equal [active.id, frozen.id, archived.id], CoffeeBag.where(id: [active.id, frozen.id, archived.id]).by_brewability.pluck(:id)
  end

  test "by_name orders bags with matching brewability and roast date" do
    zed = create(:coffee_bag, roaster:, name: "Zed", roast_date: Date.new(2024, 1, 1))
    alpha = create(:coffee_bag, roaster:, name: "Alpha", roast_date: Date.new(2024, 1, 1))

    assert_equal [alpha.id, zed.id], CoffeeBag.where(id: [zed.id, alpha.id]).by_brewability.by_roast_date.by_name.pluck(:id)
  end

  test "metadata defaults to empty hash" do
    coffee_bag = create(:coffee_bag, roaster:, metadata: nil)

    assert_equal({}, coffee_bag.metadata)
    assert_nil coffee_bag.to_api_json["metadata"]
  end

  test "to_api_json includes metadata" do
    coffee_bag = create(:coffee_bag, roaster:, metadata: {"Bean density" => "High"})

    assert_equal({"Bean density" => "High"}, coffee_bag.to_api_json["metadata"])
  end

  test "duplicate copies rich text notes" do
    coffee_bag = create(:coffee_bag, roaster:, notes: "<p><strong>Floral</strong></p>")

    duplicate = coffee_bag.duplicate(Date.new(2025, 1, 1))

    assert_equal "Floral", coffee_bag[:notes]
    assert_equal "<p><strong>Floral</strong></p>", duplicate.rich_text_html(:notes)
  end

  test "changing coffee bag enqueues refresh_shot_values job" do
    coffee_bag = create(:coffee_bag, roaster:, roast_date: Date.new(2025, 1, 1))

    assert_enqueued_with(job: CoffeeBag::RefreshShotValuesJob, args: [coffee_bag], queue: "default") do
      coffee_bag.update!(name: "Updated")
    end
  end

  test "refresh_shot_values updates every shot even when one is invalid" do
    coffee_bag = create(:coffee_bag, roaster:)
    invalid_shot = create(:shot, user:, coffee_bag:)
    valid_shot = create(:shot, user:, coffee_bag:)
    invalid_shot.fragrance = 99
    invalid_shot.save!(validate: false)
    coffee_bag.update!(name: "Renamed")

    coffee_bag.refresh_shot_values

    assert_equal "Renamed", invalid_shot.reload.bean_type
    assert_equal "Renamed", valid_shot.reload.bean_type
  end

  test "linking and unlinking a canonical coffee bag refreshes the shots' canonical coffee bag" do
    canonical_bag = CanonicalCoffeeBag.create!(name: "Ethiopia Aricha", canonical_roaster: CanonicalRoaster.create!(name: "Square Mile"))
    coffee_bag = create(:coffee_bag, roaster:)
    shot = create(:shot, user:, coffee_bag:)
    coffee_bag = CoffeeBag.find(coffee_bag.id)

    perform_enqueued_jobs { coffee_bag.update!(canonical_coffee_bag: canonical_bag) }
    assert_equal canonical_bag.id, shot.reload.canonical_coffee_bag_id

    perform_enqueued_jobs { coffee_bag.update!(canonical_coffee_bag: nil) }
    assert_nil shot.reload.canonical_coffee_bag_id
  end

  test "inherits blank descriptive fields from canonical when linked, preserving set ones" do
    canonical_roaster = CanonicalRoaster.create!(name: "Luma")
    canonical = CanonicalCoffeeBag.create!(name: "Kiambu", canonical_roaster:, roast_level: "Light", country: "Kenya", region: "Kiambu", farmer: "Smallholders", variety: "SL28", tasting_notes: "Black currant")
    coffee_bag = create(:coffee_bag, roaster:, country: nil, region: "My own region")

    coffee_bag.update!(canonical_coffee_bag: canonical)
    coffee_bag.reload

    assert_equal "Kenya", coffee_bag.country
    assert_equal "Smallholders", coffee_bag.farmer
    assert_equal "SL28", coffee_bag.variety
    assert_equal "Black currant", coffee_bag.tasting_notes
    assert_equal "Light", coffee_bag.roast_level
    assert_equal "My own region", coffee_bag.region
  end

  test "does not wipe descriptive fields when the canonical is later unlinked" do
    canonical_roaster = CanonicalRoaster.create!(name: "Luma")
    canonical = CanonicalCoffeeBag.create!(name: "Kiambu", canonical_roaster:, country: "Kenya", variety: "SL28")
    coffee_bag = create(:coffee_bag, roaster:, country: nil)
    coffee_bag.update!(canonical_coffee_bag: canonical)

    coffee_bag.update!(canonical_coffee_bag: nil)
    coffee_bag.reload

    assert_equal "Kenya", coffee_bag.country
    assert_equal "SL28", coffee_bag.variety
  end

  test "re-linking to a different canonical fills only still-blank fields" do
    canonical_roaster = CanonicalRoaster.create!(name: "Luma")
    first = CanonicalCoffeeBag.create!(name: "First", canonical_roaster:, country: "Kenya")
    second = CanonicalCoffeeBag.create!(name: "Second", canonical_roaster:, country: "Ethiopia", variety: "Heirloom")
    coffee_bag = create(:coffee_bag, roaster:, country: nil, variety: nil)

    coffee_bag.update!(canonical_coffee_bag: first)
    coffee_bag.update!(canonical_coffee_bag: second)
    coffee_bag.reload

    assert_equal "Kenya", coffee_bag.country
    assert_equal "Heirloom", coffee_bag.variety
  end

  test "leaves fields the canonical lacks untouched" do
    canonical_roaster = CanonicalRoaster.create!(name: "Luma")
    canonical = CanonicalCoffeeBag.create!(name: "Kiambu", canonical_roaster:, country: "Kenya")
    coffee_bag = create(:coffee_bag, roaster:, farm: "My Farm", quality_score: "88", place_of_purchase: "Local shop", country: nil)

    coffee_bag.update!(canonical_coffee_bag: canonical)
    coffee_bag.reload

    assert_equal "My Farm", coffee_bag.farm
    assert_equal "88", coffee_bag.quality_score
    assert_equal "Local shop", coffee_bag.place_of_purchase
    assert_equal "Kenya", coffee_bag.country
  end
end
