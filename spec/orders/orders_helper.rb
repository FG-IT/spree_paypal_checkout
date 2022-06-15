require_relative '../test_harness'

include PayPalCheckoutSdk::Orders

module OrdersHelper
  class << self
    def create_order(intent = 'CAPTURE')
      body = {
        intent: intent,
        purchase_units: [{
                          reference_id: 'test_ref_id1',
                          amount: {
                              value: '100.00',
                              currency_code: 'USD'
                          }
                        }],
        application_context: {
                          return_url: 'http://localhost:3000/paypal_checkout/confirm?payment_method_id=12&utm_nooverride=1',
                          cancel_url: 'http://localhost:3000/paypal_checkout/cancel',
                          brand_name: 'EVERYMARKET INC',
                          user_action: 'PAY_NOW'
                        }
      }
      request = OrdersCreateRequest.new()
      request.prefer("return=representation")
      request.request_body(body)

      return TestHarness::client.execute(request)
    end

    def get_order(id)
      return TestHarness::exec(OrdersGetRequest.new(id))
    end
  end
end
