class AddOidcProvisionedToUsers < ActiveRecord::Migration[8.1]
  # Accounts created by the OIDC callback get a random password nobody knows.
  # Without a flag such an account is indistinguishable from one with a real
  # password, so the unlink guard would either lock people out or refuse
  # legitimate removals. The flag is cleared when a password is reset.
  def up
    add_column :users, :oidc_provisioned, :boolean, default: false, null: false

    # Existing JIT accounts have an OIDC identity created in the same
    # transaction as the user; identities linked later are minutes or days apart.
    execute <<~SQL.squish
      UPDATE users
      SET oidc_provisioned = true
      WHERE EXISTS (
        SELECT 1
        FROM identities
        WHERE identities.user_id = users.id
          AND identities.provider = 'homelab_oidc'
          AND ABS(EXTRACT(EPOCH FROM (identities.created_at - users.created_at))) < 5
      )
    SQL
  end

  def down
    remove_column :users, :oidc_provisioned
  end
end
