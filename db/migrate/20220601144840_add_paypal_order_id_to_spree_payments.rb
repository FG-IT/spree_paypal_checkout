class AddPaypalOrderIdToSpreePayments < ActiveRecord::Migration[6.1]
  def change
    add_column :spree_payments, :paypal_order_id, :string
  end
end
