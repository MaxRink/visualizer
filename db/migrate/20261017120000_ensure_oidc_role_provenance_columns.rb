class EnsureOidcRoleProvenanceColumns < ActiveRecord::Migration[8.1]
  def up
    unless column_exists?(:identities, :oidc_role_managed)
      add_column :identities, :oidc_role_managed, :boolean, null: false, default: false
    end
    add_column :identities, :oidc_role_group, :string unless column_exists?(:identities, :oidc_role_group)
    add_column :identities, :oidc_previous_admin, :boolean unless column_exists?(:identities, :oidc_previous_admin)
    add_column :identities, :oidc_previous_developer, :boolean unless column_exists?(:identities, :oidc_previous_developer)
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "OIDC role provenance may contain live role state"
  end
end
