module SpreePaypalCheckout
  class ReauthorizationJob < ::ApplicationJob
    queue_as :default

    def perform(payment)
      if payment.source_type == "Spree::PaypalCheckout" && payment.source.state == "AUTHORIZED" && (payment.source.order_valid_time - Time.now < 1.days)
        payment.payment_method.reauthorize(payment.source)
      end
    end
  end
end