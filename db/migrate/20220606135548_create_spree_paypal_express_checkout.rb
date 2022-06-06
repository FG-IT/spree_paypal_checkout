class CreateSpreePaypalExpressCheckout < ActiveRecord::Migration[6.1]
  def change
    create_table :spree_paypal_express_checkouts do |t|
      t.string :token
      t.string :payer_id
      t.string :transaction_id
      t.string :state, :default => "complete"
      t.string :refund_transaction_id
      t.datetime :refunded_at
      t.string :refund_type
      t.datetime :created_at

      add_index :spree_paypal_express_checkouts, :transaction_id
    end
  end
end
