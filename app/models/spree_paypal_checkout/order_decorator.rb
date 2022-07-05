module SpreePaypalCheckout
  module OrderDecorator
    def self.prepended(base)
      base.has_one :paypal_checkout, class_name: "Spree::PaypalCheckout"
    end

    def sync_tracking_to_paypal_checkout(payment)
      trackers = []
      self.shipments.shipped.each do |shipment|
        trackers << {
          transaction_id: payment&.source&.transaction_id,
          status: shipment.state.upcase,
          carrier: shipment.carrier.upcase,
          tracking_number: shipment.tracking
        }
      end
      if trackers.present?
        response = payment&.payment_method&.upload_tracking(trackers)
        payment.source.update(tracking_sync: true) if response&.success?
      end
    end
  end
end

::Spree::Order.prepend SpreePaypalCheckout::OrderDecorator
