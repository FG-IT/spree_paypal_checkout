module SpreePaypalCheckout
  class SyncTrackingJob < ::ApplicationJob
    queue_as :default

    def perform(shipment_id)
      shipment = ::Spree::Shipment.find(shipment_id)
      shipment.sync_tracking_to_paypal_checkout
    end
  end
end