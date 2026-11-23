# Maps the trusted OIDC group to Visualizer's admin and developer flags. The
# roles present before the first mapping are remembered on the identity, so
# renaming or removing the group restores them instead of silently keeping
# admin.
module OidcRole
  module_function

  def matched_group(groups, trusted_group: ENV["OIDC_ADMIN_GROUP"].to_s.strip)
    return if trusted_group.blank?

    groups = groups.split if groups.is_a?(String)
    trusted_group if Array(groups).map(&:to_s).include?(trusted_group)
  end

  def apply(user, identity, group:)
    if group.present?
      unless identity.oidc_role_managed?
        identity.update!(
          oidc_role_managed: true,
          oidc_role_group: group,
          oidc_previous_admin: user.admin?,
          oidc_previous_developer: user.developer?
        )
      end

      user.update!(admin: true, developer: true)
    elsif identity.oidc_role_managed?
      user.update!(admin: identity.oidc_previous_admin?, developer: identity.oidc_previous_developer?)
      identity.update!(oidc_role_managed: false, oidc_role_group: nil)
    end
  end
end
