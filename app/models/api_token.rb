class ApiToken < ApplicationRecord
  PREFIX = "vzu_".freeze

  belongs_to :user

  # Deterministic encryption keeps the key readable on the profile page while
  # still avoiding plaintext at rest, and allows an indexed lookup by value.
  encrypts :token, deterministic: true

  validates :name, presence: true, length: {maximum: 60}
  validates :token, presence: true, uniqueness: true

  before_validation :generate_token, on: :create

  scope :active, -> { where(revoked_at: nil) }

  def self.find_active_by_token(plaintext)
    return if plaintext.blank?

    active.find_by(token: plaintext)
  end

  def revoked?
    revoked_at.present?
  end

  def revoke!
    update!(revoked_at: Time.current)
  end

  def touch_last_used
    update_column(:last_used_at, Time.current) # rubocop:disable Rails/SkipsModelValidations
  end

  def masked_token
    "#{token.first(8)}#{"*" * 12}#{token.last(4)}"
  end

  private

  def generate_token
    self.token ||= "#{PREFIX}#{SecureRandom.urlsafe_base64(32)}"
  end
end

# == Schema Information
#
# Table name: api_tokens
# Database name: primary
#
#  id           :uuid             not null, primary key
#  last_used_at :datetime
#  name         :string           default("Upload key"), not null
#  revoked_at   :datetime
#  token        :string           not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  user_id      :uuid             not null
#
# Indexes
#
#  index_api_tokens_on_token    (token) UNIQUE
#  index_api_tokens_on_user_id  (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
