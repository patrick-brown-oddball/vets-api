# This migration comes from vye (originally 20240715000014)
class IndexUserProfileInUserInfos < ActiveRecord::Migration[7.1]
  disable_ddl_transaction!

  def change
    add_index :vye_user_infos, :user_profile_id, algorithm: :concurrently, if_not_exists: true
  end
end
