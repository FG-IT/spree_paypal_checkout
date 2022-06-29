module SpreePaypalCheckout
  class SyncTrackingJob < ::ApplicationJob
    queue_as :default

    def perform(shipment)
      shipment.sync_tracking_to_payment
    end
  end
end