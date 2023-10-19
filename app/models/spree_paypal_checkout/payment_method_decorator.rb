module SpreePaypalCheckout
  module PaymentMethodDecorator
    def self.prepended(base)
      base.after_save :update_cache
    end

    def update_cache
      ::Spree::PaypalCheckout.paypal_checkout_payment_methods(true)
    end
  end
end

::Spree::PaymentMethod.prepend ::SpreePaypalCheckout::PaymentMethodDecorator