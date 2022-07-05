class AddTrackingSyncToPaypalCheckout < ActiveRecord::Migration[6.1]
  def up
    add_column :spree_paypal_checkouts, :tracking_sync, :boolean, default: false
  end

  def down
    remove_column :spree_paypal_checkouts, :tracking_sync
  end
end
