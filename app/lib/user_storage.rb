# Storage used by one account: shot images plus the avatar. Two aggregate
# queries, scoped to the user, so a shared instance can show per-person usage
# without counting the whole bucket.
class UserStorage
  def initialize(user)
    @user = user
  end

  def bytes
    shot_bytes + avatar_bytes
  end

  private

  def shot_bytes
    ActiveStorage::Blob.where(id: shot_attachments.select(:blob_id)).sum(:byte_size)
  end

  def shot_attachments
    ActiveStorage::Attachment.where(record_type: "Shot", record_id: @user.shots.select(:id))
  end

  def avatar_bytes
    attachment = ActiveStorage::Attachment.find_by(record_type: "User", record_id: @user.id, name: "avatar")
    return 0 unless attachment

    ActiveStorage::Blob.where(id: attachment.blob_id).sum(:byte_size)
  end
end
