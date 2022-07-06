module SpreePaypalCheckout
  class SyncAllTrackingJob < ::ApplicationJob
    queue_as :default

    def perform
      ::Spree::PaypalCheckout.completed.not_sync.each do |paypal|
        paypal.order.shipments.shipped.each do |shipment|
          SpreePaypalCheckout::SyncTrackingJob.perform_later(shipment.id)
        end
      end
    end
  end
end