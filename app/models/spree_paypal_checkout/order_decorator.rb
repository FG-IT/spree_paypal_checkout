module SpreePaypalCheckout
  module OrderDecorator
    def self.prepended(base)
      base.has_one :paypal_checkout, class_name: "Spree::PaypalCheckout"
    end

    def sync_tracking_to_paypal_checkout(payment)
      trackers = []

      self.shipments.each do |shipment|
        if shipment.state == "shipped"
          trackers << {
            transaction_id: payment.source.transaction_id,
            status: shipment.state.upcase,
            carrier: shipment.carrier.upcase,
            tracking_number: shipment.tracking
          }
        end
      end

      response = payment.payment_method.upload_tracking(trackers)
      if response.success?
        payment.source.update(tracking_sync: true)
      end
    end
  end
end

::Spree::Order.prepend SpreePaypalCheckout::OrderDecorator
