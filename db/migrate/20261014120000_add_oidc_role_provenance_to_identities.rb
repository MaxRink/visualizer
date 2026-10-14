class AddOidcRoleProvenanceToIdentities < ActiveRecord::Migration[8.1]
  def change
    add_column :identities, :oidc_role_managed, :boolean, null: false, default: false
    add_column :identities, :oidc_role_group, :string
    add_column :identities, :oidc_previous_admin, :boolean
    add_column :identities, :oidc_previous_developer, :boolean
  end
end
