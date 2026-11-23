# Read the git metadata once at boot instead of shelling out on every /health
# request. Without git (or a checkout) the REVISION/env fallbacks take over.
Rails.application.config.after_initialize do
  Instance.warm_git_metadata
end
