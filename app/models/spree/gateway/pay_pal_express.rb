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

    def authorize(amount, express_checkout, gateway_options = {})
      request = ::PayPalCheckoutSdk::Orders::OrdersAuthorizeRequest::new(order_id)
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
      paypal_order_id, payment = find_payment_and_paypal_order_id(gateway_options)

      request = ::PayPalCheckoutSdk::Orders::OrdersCaptureRequest::new(paypal_order_id)
      request.prefer("return=representation")
      #Below request bodyn can be updated with fields as per business need. Please refer API docs for more info.
      request.request_body({})
      begin
        response = provider.execute(request)
        Spree::PaypalExpressCheckout.find_by(authorization_id: authorization_id).update(state: 'completed')
        return response
      rescue PayPalHttp::HttpError => ioe
        # Exception occured while processing the refund.
        logger.info  " Status Code: #{ioe.status_code}"
        logger.info  " Debug Id: #{ioe.result.debug_id}"
        logger.info  " Response: #{ioe.result}"
      end
    end

    def purchase(amount, express_checkout, gateway_options = {})
      paypal_order_id, payment = find_payment_and_paypal_order_id(gateway_options)
      request = ::PayPalCheckoutSdk::Orders::OrdersCaptureRequest::new(paypal_order_id)
      request.prefer("return=representation")
      #Below request bodyn can be updated with fields as per business need. Please refer API docs for more info.
      request.request_body({})
      begin
        response = provider.execute(request)
        Spree::PaypalExpressCheckout.find_by(authorization_id: authorization_id).update(state: 'completed')
        return response
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

      paypal_order_id, payment = find_payment_and_paypal_order_id(gateway_options)
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
        if response.success?
          payment.source.update({
                                  :refunded_at => Time.now,
                                  :refund_transaction_id => response.id,
                                  :state => "refunded",
                                  :refund_type => refund_type
                                })
        end
      rescue PayPalHttp::HttpError => ioe
        # Exception occured while processing the refund.
        puts " Status Code: #{ioe.status_code}"
        puts " Debug Id: #{ioe.result.debug_id}"
        puts " Response: #{ioe.result}"
      end
     
      if refund_transaction_response.success?
        payment.source.update({
                                  :refunded_at => Time.now,
                                  :refund_transaction_id => refund_transaction_response.RefundTransactionID,
                                  :state => "refunded",
                                  :refund_type => refund_type
                              })
      end
      refund_transaction_response
    end

    private

    def find_payment_and_paypal_order_id(gateway_options)
      paypal_order_id = gateway_options[:order_id].split('-')[-1]
      payment = Spree::Payment.find_by(number: paypal_order_id)
      [paypal_order_id, payment]
    end

    def find_payment_and_paypal_authorization_id(gateway_options)
      paypal_authorization_id = gateway_options[:order_id].split('-')[-1]
      payment = Spree::Payment.find_by(number: paypal_order_id)
      [paypal_authorization_id, payment]
    end
    
    def sale(amount, express_checkout, payment_action, gateway_options = {})
      pp_details_request = provider.build_get_express_checkout_details({
                                                                          :Token => express_checkout.token
                                                                      })
      pp_details_response = provider.get_express_checkout_details(pp_details_request)

      pp_request = provider.build_do_express_checkout_payment({
                                                                  :DoExpressCheckoutPaymentRequestDetails => {
                                                                      :PaymentAction => payment_action,
                                                                      :Token => express_checkout.token,
                                                                      :PayerID => express_checkout.payer_id,
                                                                      :PaymentDetails => pp_details_response.get_express_checkout_details_response_details.PaymentDetails
                                                                  }
                                                              })

      pp_response = provider.do_express_checkout_payment(pp_request)


      if pp_response.success?
        # We need to store the transaction id for the future.
        # This is mainly so we can use it later on to refund the payment if the user wishes.
        begin
          transaction_id = pp_response.do_express_checkout_payment_response_details.payment_info.first.transaction_id
        rescue
          transaction_id = pp_response.do_express_checkout_payment_response_details.payment_info.transaction_id
        end

        express_checkout.update_column(:transaction_id, transaction_id)

        Response.new(true, nil, {:id => transaction_id})

      else
        class << pp_response
          def to_s
            errors.map(&:long_message).join(" ")
          end
        end

        Response.new(false, pp_response, nil)

      end
    end
  end
end