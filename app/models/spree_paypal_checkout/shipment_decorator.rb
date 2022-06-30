module SpreePaypalCheckout
  module ShipmentDecorator

    def self.prepended(base)
      base.after_save :sync_tracking_to_paypal_checkout
    end

    def sync_tracking_to_paypal_checkout
      self.order.payments.completed.each do |payment|
        if payment.source_type == "Spree::PaypalCheckout"
          trackers =[{
            transaction_id: payment.source.transaction_id,
            status: self.state.upcase,
            carrier: self.carrier.upcase,
            tracking_number: self.tracking
          }]
          response = payment.payment_method.upload_tracking(trackers)
          if response.success?
            payment.source.update(tracking_sync: true)
          end
        end
      end
    end

    private

    def sync_tracking
      SpreePaypalCheckout::SyncTrackingJob.perform_later(self)
    end
  end
end

::Spree::Shipment.prepend SpreePaypalCheckout::ShipmentDecorator
