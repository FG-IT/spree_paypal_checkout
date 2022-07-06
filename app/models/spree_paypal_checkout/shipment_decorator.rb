module SpreePaypalCheckout
  module ShipmentDecorator

    def self.prepended(base)
      base.after_save :sync_tracking
    end

    def sync_tracking_to_paypal_checkout
      self.order.payments.completed.each do |payment|
        if payment.source_type == "Spree::PaypalCheckout" && !payment.source.tracking_sync
          trackers = [{
            transaction_id: payment&.source&.transaction_id,
            status: "SHIPPED",
            carrier: self.carrier.upcase,
            tracking_number: self.tracking
          }]
          begin
            response = payment&.payment_method&.upload_tracking(trackers)
            payment.source.update(tracking_sync: true) if response&.success?
          rescue => exception
            Rails.logger.error(exception)
          end
        end
      end
    end

    private

    def sync_tracking
      if self.carrier.present? && self.tracking.present?
        if Rails.env.production?
          SpreePaypalCheckout::SyncTrackingJob.perform_later(self.id)
        else
          sync_tracking_to_paypal_checkout
        end
      end
    end
  end
end

::Spree::Shipment.prepend SpreePaypalCheckout::ShipmentDecorator
