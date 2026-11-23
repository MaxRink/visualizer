class AddUpstreamPushToShots < ActiveRecord::Migration[8.1]
  def change
    add_column :shots, :upstream_pushed_at, :datetime
    add_column :shots, :upstream_shot_id, :string
    add_column :shots, :upstream_push_error, :text
  end
end
