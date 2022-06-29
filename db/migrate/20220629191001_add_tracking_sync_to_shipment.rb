class AddTrackingSyncToShipment < ActiveRecord::Migration[6.1]
  def up
    add_column :spree_shipments, :tracking_sync, :tinyint, default: 0
  end

  def down
    remove_column :spree_shipments, :tracking_sync
  end
end
