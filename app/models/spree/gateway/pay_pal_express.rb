module Spree
  class Gateway::PayPalExpress < Gateway
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
      begin
        response = provider.execute(request)
        
      rescue PayPalHttp::HttpError => ioe
        # Exception occured while processing the refund.
        puts " Status Code: #{ioe.status_code}"
        puts " Debug Id: #{ioe.result.debug_id}"
        puts " Response: #{ioe.result}"
      end
    end

    def settle(amount, checkout, gateway_options) end

    def capture(amount, checkout, gateway_options)
      request = ::PayPalCheckoutSdk::Orders::OrdersCaptureRequest::new(checkout.token)
      request.prefer("return=representation")
      #Below request bodyn can be updated with fields as per business need. Please refer API docs for more info.
      request.request_body({})
      begin
        response = provider.execute(request)
        Spree::PaypalExpressCheckout.find_by(authorization_id: authorization_id).update(state: 'completed')
        return response
        return Response.new(true, nil, {:id => new_transaction_id})
      rescue PayPalHttp::HttpError => ioe
        # Exception occured while processing the refund.
        logger.info  " Status Code: #{ioe.status_code}"
        logger.info  " Debug Id: #{ioe.result.debug_id}"
        logger.info  " Response: #{ioe.result}"
      end
    end

    def purchase(amount, checkout, gateway_options = {})

      request = ::PayPalCheckoutSdk::Orders::OrdersCaptureRequest::new(checkout.token)
      request.prefer("return=representation")
      #Below request bodyn can be updated with fields as per business need. Please refer API docs for more info.
      request.request_body({})
      begin
        response = provider.execute(request)
        result = openstruct_to_hash(response)[:result]
        authorization_id = result[:purchase_units].first[:payments][:captures].first[:id]
        checkout.update(state: 'completed', transaction_id: authorization_id)
        return Response.new(true, nil, {:id => authorization_id})
      rescue PayPalHttp::HttpError => ioe
        # Exception occured while processing the refund.
        logger.info  " Status Code: #{ioe.status_code}"
        logger.info  " Debug Id: #{ioe.result.debug_id}"
        logger.info  " Response: #{ioe.result}"
      end
    end

    def credit(credit_cents, transaction_id, _options)
      payment = _options[:originator].payment
      refund(transaction_id, payment, credit_cents)
    end

    def cancel(response_code, _source, payment)
      if response_code.nil?
        source = _source
      else
        source = Spree::PaypalExpressCheckout.find_by(token: response_code)
      end

      if payment.present? and source.can_credit? payment
        refund(nil, payment, payment.money.amount_in_cents)
      else
        void(source.transaction_id, source, nil)
      end
    end

    def void(response_code, _source, gateway_options)
      payment = find_payment(gateway_options)
      authorization_id, payment = find_payment_and_paypal_authorization_id(gateway_options)
      request = ::PayPalCheckoutSdk::Payments::AuthorizationsVoidRequest::new(authorization_id)

      #Below request bodyn can be updated with fields as per business need. Please refer API docs for more info.
      request.request_body({})
      begin
        response = provider.execute(request)
        Spree::PaypalExpressCheckout.find_by(transaction_id: source.transaction_id).update(state: 'voided')
        return response
      rescue PayPalHttp::HttpError => ioe
        # Exception occured while processing the refund.
        logger.info  " Status Code: #{ioe.status_code}"
        logger.info  " Debug Id: #{ioe.result.debug_id}"
        logger.info  " Response: #{ioe.result}"
      end
      if _source.present?
        source = _source
      else
        source = Spree::PaypalExpressCheckout.find_by(token: response_code)
      end

      void_transaction = provider.build_do_void({
                                                  :AuthorizationID => source.transaction_id
                                                })

      do_void_response = provider.do_void(void_transaction)

      if do_void_response.success?
        Spree::PaypalExpressCheckout.find_by(transaction_id: source.transaction_id).update(state: 'voided')
        # This is rather hackish, required for payment/processing handle_response code.
        Class.new do
          def success?
            true;
          end

          def authorization
            nil;
          end
        end.new
      else
        class << do_void_response
          def to_s
            errors.map(&:long_message).join(" ")
          end
        end

        do_void_response
      end
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

      begin
        response = provider.execute(request)
        payment.source.update({
                                :refunded_at => Time.now,
                                :refund_transaction_id => response.id,
                                :state => "refunded",
                                :refund_type => refund_type
                              })
        result = openstruct_to_hash(response)[:result]
        return Response.new(true, nil, {:id => result[:id]})
      rescue PayPalHttp::HttpError => ioe
        # Exception occured while processing the refund.
        puts " Status Code: #{ioe.status_code}"
        puts " Debug Id: #{ioe.result.debug_id}"
        puts " Response: #{ioe.result}"
      end
    end

    private

    def openstruct_to_hash(object, hash = {})
      object.each_pair do |key, value|
        hash[key] = value.is_a?(OpenStruct) ? openstruct_to_hash(value) : value.is_a?(Array) ? array_to_hash(value) : value
      end
      hash
    end

    def array_to_hash(array, hash= [])
      array.each do |item|
        x = item.is_a?(OpenStruct) ? openstruct_to_hash(item) : item.is_a?(Array) ? array_to_hash(item) : item
        hash << x
      end
      hash
    end
  end
end