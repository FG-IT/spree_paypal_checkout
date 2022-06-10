module Spree
  class Gateway::PayPalCheckout < Gateway
    preference :paypal_client_id, :string
    preference :paypal_client_secret, :string
    preference :server, :string, default: 'sandbox'
    preference :auto_capture, :integer, default: 0
    preference :no_shipping, :integer, default: 0

    def supports?(source)
      true
    end

    def method_type
      'paypal'
    end

    def provider_class
      ::PayPal::PayPalHttpClient
    end

    def environment
      if preferred_server.present? && preferred_server == "live"
        ::PayPal::LiveEnvironment.new(preferred_paypal_client_id, preferred_paypal_client_secret)
      else
        ::PayPal::SandboxEnvironment.new(preferred_paypal_client_id, preferred_paypal_client_secret)
      end
    end

    def provider
      @provider ||= provider_class.new(self.environment)
    end

    def authorize(amount, checkout, gateway_options = {})
      request = ::PayPalCheckoutSdk::Orders::OrdersAuthorizeRequest::new(checkout.token)
      request.prefer("return=representation")
      # This request body can be updated with fields as per requirement. Please refer API docs for more info.
      request.request_body({})
      response = provider.execute(request)
      result = ::PaypalServices::Response::openstruct_to_hash(response)[:result]
      return Response.new(true, nil, {:id => result[:id]})
    end

    def settle(amount, checkout, gateway_options) end

    def capture(amount, checkout, gateway_options)
      request = ::PayPalCheckoutSdk::Orders::OrdersCaptureRequest::new(checkout.token)
      request.prefer("return=representation")
      #Below request bodyn can be updated with fields as per business need. Please refer API docs for more info.
      request.request_body({})
      response = provider.execute(request)
      result = ::PaypalServices::Response::openstruct_to_hash(response)[:result]
      authorization_id = result[:purchase_units].first[:payments][:captures].first[:id]
      checkout.update(state: 'completed', transaction_id: authorization_id)
      return Response.new(true, nil, {:id => authorization_id})
    end

    def purchase(amount, checkout, gateway_options = {})

      request = ::PayPalCheckoutSdk::Orders::OrdersCaptureRequest::new(checkout.token)
      request.prefer("return=representation")
      #Below request bodyn can be updated with fields as per business need. Please refer API docs for more info.
      request.request_body({})
      response = provider.execute(request)
      result = ::PaypalServices::Response::openstruct_to_hash(response)[:result]
      authorization_id = result[:purchase_units].first[:payments][:captures].first[:id]
      checkout.update(state: 'completed', transaction_id: authorization_id)
      return Response.new(true, nil, {:id => authorization_id})
    end

    def credit(credit_cents, transaction_id, _options)
      payment = _options[:originator].payment
      refund(transaction_id, payment, credit_cents)
    end

    def cancel(response_code, _source, payment)
      if response_code.nil?
        source = _source
      else
        source = Spree::PaypalCheckout.find_by(token: response_code)
      end

      if payment.present? and source.can_credit? payment
        refund(nil, payment, payment.money.amount_in_cents)
      else
        void(source.transaction_id, source, nil)
      end
    end

    def void(response_code, _source, gateway_options)

      if _source.present?
        source = _source
      else
        source = Spree::PaypalCheckout.find_by(token: response_code)
      end
      authorization_id = source.transaction_id
      request = ::PayPalCheckoutSdk::Payments::AuthorizationsVoidRequest::new(authorization_id)
      #Below request bodyn can be updated with fields as per business need. Please refer API docs for more info.
      response = provider.execute(request)
      source.update(state: 'voided')
      result = ::PaypalServices::Response::openstruct_to_hash(response)[:result]
      return Response.new(true, nil, {:id => result[:id]})
    end

    def refund(capture_id, payment, credit_cents)
      unless capture_id.present?
        capture_id = payment.source.capture_id
      end
      request = ::PayPalCheckoutSdk::Payments::CapturesRefundRequest::new(capture_id)

      refund_type = payment.money.amount_in_cents == credit_cents ? "Full" : "Partial"
      params = {
        :amount => {
          :currency_code => payment.currency,
          :value => credit_cents.to_f / 100
        }
      }
      logger.info params
      request.request_body(params);
      response = provider.execute(request)
      result = ::PaypalServices::Response::openstruct_to_hash(response)[:result]
      payment.source.update({
                              :refunded_at => Time.now,
                              :refund_transaction_id => result[:id],
                              :state => "refunded",
                              :refund_type => refund_type
                            })
      result = ::PaypalServices::Response::openstruct_to_hash(response)[:result]
      return Response.new(true, nil, {:id => result[:id]})
    end
  end
end