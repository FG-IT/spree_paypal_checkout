module Spree
  class Gateway::PayPalCheckout < Gateway
    preference :paypal_client_id, :string
    preference :paypal_client_secret, :string
    preference :brand_name, :string
    preference :pay_later_text_size, :integer
    preference :show_in_cart, :boolean

    def supports?(source)
      true
    end

    def method_type
      'paypal_checkout'
    end

    def provider_class
      ::PayPal::PayPalHttpClient
    end

    def environment
      if preferred_test_mode
        ::PayPal::SandboxEnvironment.new(preferred_paypal_client_id, preferred_paypal_client_secret)
      else
        ::PayPal::LiveEnvironment.new(preferred_paypal_client_id, preferred_paypal_client_secret)
      end
    end

    def provider
      @provider ||= provider_class.new(self.environment)
    end

    def authorize(amount, checkout, gateway_options = {})
      request = ::PayPalCheckoutSdk::Orders::OrdersAuthorizeRequest::new(checkout.token)
      request.pay_pal_request_id(checkout.token)
      response = ::PaypalServices::Request.request_paypal(provider, request)
      if response.success?
        transaction_id = response.result[:purchase_units].first[:payments][:authorizations].first[:id]
        checkout.update(state: :AUTHORIZED, transaction_id: transaction_id)
        response.update_authorization(transaction_id)
      end
      response
    end

    def upload_tracking(trackers)
      request = ::PayPalCheckoutSdk::TrackingUploadRequest::new
      response = ::PaypalServices::Request.request_paypal(provider, request, trackers: trackers)
      response
    end

    def update_tracking(transaction_id, tracking_number, status, carrier)
      request = ::PayPalCheckoutSdk::TrackingUpdateRequest::new(transaction_id, tracking_number)
      tracker = {
        transaction_id: transaction_id,
        status: status,
        carrier: carrier,
        tracking_number: tracking_number
      }
      response = ::PaypalServices::Request.request_paypal(provider, request, tracker)
      response
    end

    def show_tracking(transaction_id, tracking_number)
      request = ::PayPalCheckoutSdk::TrackingShowRequest::new(transaction_id, tracking_number)
      response = ::PaypalServices::Request.request_paypal(provider, request)
      response
    end

    def authorization_info(checkout)
      request = ::PayPalCheckoutSdk::Payments::AuthorizationsGetRequest::new(checkout.transaction_id)
      response = ::PaypalServices::Request.request_paypal(provider, request)
      response
    end

    def reauthorize(checkout)
      request = ::PayPalCheckoutSdk::Payments::AuthorizationsReauthorizeRequest::new(checkout.transaction_id)
      response = ::PaypalServices::Request.request_paypal(provider, request)
      if response.success?
        transaction_id = response.result[:id]
        checkout.update(state: :AUTHORIZED, transaction_id: transaction_id)
        response.update_authorization(transaction_id)
      end
      response
    end

    def settle(amount, checkout, gateway_options) end

    def capture(credit_cents, transaction_id, gateway_options)
      payment_id = gateway_options[:order_id].split('-')[-1]
      payment = Spree::Payment.find_by(number: payment_id)
      if payment.source.state == "AUTHORIZED"
        request = ::PayPalCheckoutSdk::Payments::AuthorizationsCaptureRequest::new(payment.source.transaction_id)
        request.pay_pal_request_id(payment.source.transaction_id)
        response = ::PaypalServices::Request.request_paypal(provider, request)
        
        if response.success?
          transaction_id = response.result[:id]
          payment.source.update(state: :COMPLETED, transaction_id: transaction_id)   
          response.update_authorization(transaction_id) 
        end
        response
      else
        Response.new(true, nil, {:id => payment.source.transaction_id})
      end
    end

    def purchase(amount, checkout, gateway_options = {})
      request = ::PayPalCheckoutSdk::Orders::OrdersCaptureRequest::new(checkout.token)
      request.pay_pal_request_id(checkout.token)
      response = ::PaypalServices::Request.request_paypal(provider, request)
      if response.success?
        transaction_id = response.result[:purchase_units].first[:payments][:captures].first[:id]
        checkout.update_columns(transaction_id: transaction_id, state: :COMPLETED)
        response.update_authorization(transaction_id)
      end
      response
    end

    def credit(credit_cents, transaction_id, _options)
      payment = _options[:originator].payment
      refund(transaction_id, payment, credit_cents)
    end

    def cancel(response_code, _source, payment)
      if response_code.nil?
        source = _source
      else
        source = Spree::PaypalCheckout.find_by(transaction_id: response_code)
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
        source = Spree::PaypalCheckout.find_by(transaction_id: response_code)
      end

      if source.state == "AUTHORIZED"
        request = ::PayPalCheckoutSdk::Payments::AuthorizationsVoidRequest::new(source.transaction_id)
        response = ::PaypalServices::Request.request_paypal(provider, request)
        if response.success?
          transaction_id = response.result[:id]
          source.update(state: :VOIDED)
          response.update_authorization(transaction_id)
        end
        response
      else
        Response.new(true, nil, {:id => source.transaction_id})
      end
    end

    def refund(transaction_id, payment, credit_cents)
      unless transaction_id.present?
        transaction_id = payment.source.transaction_id
      end
      request = ::PayPalCheckoutSdk::Payments::CapturesRefundRequest::new(transaction_id)
      request.pay_pal_request_id(payment.source.refund_transaction_id || transaction_id)
      refund_type = payment.money.amount_in_cents == credit_cents ? "Full" : "Partial"
      params = {
        :amount => {
          :currency_code => payment.currency,
          :value => credit_cents.to_f / 100
        }
      }
      logger.info params
      
      response = ::PaypalServices::Request.request_paypal(provider, request, params)

      if response.success?
        transaction_id = response.result[:id]
        payment.source.update({
          :refunded_at => Time.now,
          :refund_transaction_id => transaction_id,
          :state => :REFUNDED,
          :refund_type => refund_type
        })
        response.update_authorization(transaction_id)
      end
      response
    end
  end
end