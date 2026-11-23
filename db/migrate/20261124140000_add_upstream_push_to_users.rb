class AddUpstreamPushToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :upstream_push_enabled, :boolean, default: false, null: false
    add_column :users, :upstream_api_token, :string
    add_column :users, :upstream_base_url, :string, default: "https://visualizer.coffee"
    add_column :users, :upstream_push_checked_at, :datetime
  end
end
