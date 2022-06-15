
require_relative '../test_harness'
require_relative '../orders/orders_helper'
require 'json'
require 'selenium-webdriver'


include ::PayPalCheckoutSdk::Orders

describe Spree::Gateway::PayPalCheckout do
  let(:gateway) { Spree::Gateway::PayPalCheckout.create!(name: "PayPalCheckout", preferred_paypal_client_id: TestHarness::environment.client_id, preferred_paypal_client_secret: TestHarness::environment.client_secret, preferred_server: "sandbox") }
  let(:paypal_order_response) {
    ::PaypalServices::Response.new(OrdersHelper::create_order)
  }
  context "payment purchase" do
    let(:paypal_order) {
      resp = OrdersHelper::create_order
    }
    let(:order) { Spree::Order.create }
    let(:payment) do
      payment = Spree::Payment.new
      payment.payment_method = gateway
      payment.amount = 100
      payment.order = order
      payment
    end

    let(:provider) { TestHarness.client }

    before do
      resp = OrdersHelper::create_order
      puts resp.result.links
      name = gets.chomp
      payment.source = order.create_paypal_checkout(token: resp.result.id, state: resp.result.status, order_valid_time: Time.now + 2*60*60)
      binding.pry

      authorize_resp = OrdersHelper::create_order("authorize")
      puts resp.result.links
      name = gets.chomp
      payment.source = order.create_paypal_checkout(token: authorize_resp.result.id, state: authorize_resp.result.status, order_valid_time: Time.now + 2*60*60)
      binding.pry
    end

    # Test for #11
    it "purchase" do 
      expect(lambda { payment.purchase! }).to_not raise_error
    end

    it "refund" do 
      payment.purchase!
      expect(lambda { response = payment.payment_method.refund(payment.source.transaction_id, payment, 100) }).to_not raise_error
    end

    it "authorize" do 
      expect(lambda { payment.authorize! }).to_not raise_error
    end

    it "void" do 
      expect(lambda { payment.void_transaction! }).to_not raise_error
    end

    # Test for #4
    
  end
end
