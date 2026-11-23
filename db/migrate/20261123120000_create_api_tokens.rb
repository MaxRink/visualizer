class CreateApiTokens < ActiveRecord::Migration[8.1]
  def change
    create_table :api_tokens, id: :uuid do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.string :name, null: false, default: "Upload key"
      t.string :token, null: false
      t.datetime :last_used_at
      t.datetime :revoked_at
      t.timestamps

      t.index :token, unique: true
    end
  end
end
