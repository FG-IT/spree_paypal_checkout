module SpreePaypalCheckout
  module ShipmentDecorator

    def self.prepended(base)
      base.scope :not_sync, -> { where(tracking_sync: 0)}
      base.after_save :sync_tracking, if: :not_sync_yet
    end

    def sync_tracking_to_payment
      update(tracking_sync: 1)
      self.order.payments.each do |payment|
        if payment.payment_method.has_attribute?(:preferred_need_tracking) && payment.payment_method.preferred_need_tracking
          response = payment.payment_method.upload_tracking(payment.source.transaction_id, tracking, "SHIPPED", carrier)
          if response.success?
            update(tracking_sync: 2)
          end
        end
      end
    end

    private

    def not_sync_yet
      self.sync_tracking == 0
    end

    def sync_tracking
      SpreePaypalCheckout::SyncTrackingJob.perform_later(self)
    end
  end
end

::Spree::Shipment.prepend SpreePaypalCheckout::ShipmentDecorator
