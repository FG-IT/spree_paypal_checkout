module SpreePaypalCheckout
  class SyncAllTrackingJob < ::ApplicationJob
    queue_as :default

    def perform()
      ::Spree::Shipment.shipped.not_sync.each do |shipment|
        SpreePaypalCheckout::SyncTrackingJob.perform_later(shipment)
      end
    end
  end
end