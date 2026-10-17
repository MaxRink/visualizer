require "test_helper"
require Rails.root.join("db/migrate/20261017120000_ensure_oidc_role_provenance_columns")

class EnsureOidcRoleProvenanceColumnsTest < ActiveSupport::TestCase
  test "leaves existing role provenance intact when rerun" do
    identity = create(:identity)
    identity.update!(
      oidc_role_managed: true,
      oidc_role_group: "homelab-admins",
      oidc_previous_admin: false,
      oidc_previous_developer: true
    )

    EnsureOidcRoleProvenanceColumns.new.migrate(:up)
    EnsureOidcRoleProvenanceColumns.new.migrate(:up)

    assert_equal [true, "homelab-admins", false, true], identity.reload.attributes.values_at(
      "oidc_role_managed",
      "oidc_role_group",
      "oidc_previous_admin",
      "oidc_previous_developer"
    )
  end

  test "adds missing provenance columns to an existing identities table" do
    identity = create(:identity)
    connection = ActiveRecord::Base.connection

    %i[oidc_previous_developer oidc_previous_admin oidc_role_group oidc_role_managed].each do |column|
      connection.remove_column(:identities, column)
    end
    Identity.reset_column_information

    EnsureOidcRoleProvenanceColumns.new.migrate(:up)
    Identity.reset_column_information

    updated_identity = identity.reload
    assert_equal identity.user_id, updated_identity.user_id
    assert_equal false, updated_identity.oidc_role_managed
    assert_nil updated_identity.oidc_role_group
    assert_nil updated_identity.oidc_previous_admin
    assert_nil updated_identity.oidc_previous_developer
  ensure
    EnsureOidcRoleProvenanceColumns.new.migrate(:up)
    Identity.reset_column_information
  end
end
