class CreateSpreePaypalCheckout < ActiveRecord::Migration[6.1]
  def change
    create_table :spree_paypal_checkouts do |t|
      t.string :token
      t.string :payer_id
      t.integer :order_id
      t.string :transaction_id
      t.string :state, :default => "complete"
      t.string :refund_transaction_id
      t.datetime :refunded_at
      t.string :refund_type
      t.datetime :created_at

      t.index [:order_id], name: "index_spree_paypal_checkouts_on_order_id"
      t.index [:transaction_id], name: "index_spree_paypal_checkouts_on_transaction_id"
    end
  end
end
