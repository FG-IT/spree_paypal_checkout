module Paypal
  module PaymentDecorator

    def cancel!
      if payment_method.is_a?(Spree::Gateway::PayPalExpress)
        response = payment_method.cancel(response_code, source, self)
      else
        response = payment_method.cancel(response_code)
      end
      handle_response(response, :void, :failure)
    end

    attr_reader :redirect_uri, :popup_uri

    def complete!(payer_id = nil)
      if self.recurring?
        response = client.subscribe!(self.token, recurring_request)
        self.identifier = response.recurring.identifier
      else
        response = client.checkout!(self.token, payer_id, payment_request)
        self.payer_id = payer_id
        self.identifier = response.payment_info.first.transaction_id
      end
      self.completed = true
      self.save!
      self
    end

    def payment_method
      # Spree::PaymentMethod.find(params[:payment_method_id])
      Spree::PaymentMethod.find(8)
    end

    def client
      payment_method.provider_express
    end

    DESCRIPTION = {
      item: 'PayPal Express Sample Item',
      instant: 'PayPal Express Sample Instant Payment',
      recurring: 'PayPal Express Sample Recurring Payment'
    }

    def payment_request
      item = {
        name: DESCRIPTION[:item],
        description: DESCRIPTION[:item],
        amount: 10
      }

      request_attributes = {
        amount: 10,
        description: DESCRIPTION[:instant],
        # items: [item]
      }

      ::Paypal::Payment::Request.new request_attributes
    end

    def void_transaction!
      return true if void?

      protect_from_connection_error do
        if payment_method.payment_profiles_supported? or payment_method.is_a?(Spree::Gateway::PayPalExpress)
          # Gateways supporting payment profiles will need access to credit card object because this stores the payment profile information
          # so supply the authorization itself as well as the credit card, rather than just the authorization code
          response = payment_method.void(response_code, source, gateway_options)
        else
          # Standard ActiveMerchant void usage
          response = payment_method.void(response_code, gateway_options)
        end

        record_response(response)

        if response.success?
          self.response_code = response.authorization
          void
        else
          gateway_error(response)
        end
      end
    end
  end
end

::Spree::Payment.prepend Paypal::PaymentDecorator
