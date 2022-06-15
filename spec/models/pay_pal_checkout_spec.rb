
require_relative '../test_harness'
require_relative '../orders/orders_helper'
require 'json'
require 'selenium-webdriver'


include ::PayPalCheckoutSdk::Orders

describe Spree::Gateway::PayPalCheckout do
  let(:gateway) { Spree::Gateway::PayPalCheckout.create!(name: "PayPalCheckout", preferred_paypal_client_id: TestHarness::environment.client_id, preferred_paypal_client_secret: TestHarness::environment.client_secret, preferred_server: "sandbox") }
  context "payment purchase" do
    let(:order) { Spree::Order.create }
    let(:payment) do
      payment = Spree::Payment.new
      payment.payment_method = gateway
      payment.amount = 100
      payment.order = order
      payment
    end

    let(:provider) { TestHarness.client }

    context "pay now" do
      before do
        resp = OrdersHelper::create_order
        puts resp.result.links
        cont = $stdin.gets
        payment.source = order.create_paypal_checkout(token: resp.result.id, state: resp.result.status, order_valid_time: Time.now + 2*60*60)       
        payment.save
      end

      it "purchase" do
        capture_event = payment.purchase!
        expect(capture_event.amount).to eq(100)
      end

      it "refund" do 
        payment.purchase!
        response = payment.payment_method.refund(payment.source.transaction_id, payment, 100)
        expect(response.success?).to be_truthy
        expect(response.result[:amount][:value].to_i).to eq(100)
      end
    end
    
    context "AUTHORIZE" do
      before do
        authorize_resp = OrdersHelper::create_order("AUTHORIZE")
        puts authorize_resp.result.links
        cont = $stdin.gets
        payment.source = order.create_paypal_checkout(token: authorize_resp.result.id, state: authorize_resp.result.status, order_valid_time: Time.now + 2*60*60)
        payment.save
      end

      it "authorize" do 
        authorize_event = payment.authorize!
        expect(authorize_event).to be_truthy
      end

      it "capture" do
        payment.authorize!
        capture_event = payment.capture!
        expect(capture_event).to be_truthy
      end

      it "void" do
        payment.authorize!
        void = payment.void_transaction!
        expect(void).to be_truthy
      end
    end
  end
end
