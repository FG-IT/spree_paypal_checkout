module SpreePaypalCheckout
  module OrderDecorator
    def self.prepended(base)
      base.has_one :paypal_checkout, class_name: "Spree::PaypalCheckout"
    end
  end
end

::Spree::Order.prepend SpreePaypalCheckout::OrderDecorator
