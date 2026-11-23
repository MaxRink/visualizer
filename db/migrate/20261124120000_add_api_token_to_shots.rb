class AddApiTokenToShots < ActiveRecord::Migration[8.1]
  def change
    # Nullable attribution: shots uploaded by hand or before this column keep
    # working, and deleting a key nullifies the row instead of touching history.
    add_reference :shots, :api_token, type: :uuid, null: true, foreign_key: {on_delete: :nullify}, index: true
  end
end
