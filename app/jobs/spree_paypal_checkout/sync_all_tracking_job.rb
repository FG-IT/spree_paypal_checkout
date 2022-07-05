module SpreePaypalCheckout
  class SyncAllTrackingJob < ::ApplicationJob
    queue_as :default

    def perform
      ::Spree::PaypalCheckout.completed.not_sync.each do |paypal|
        SpreePaypalCheckout::SyncTrackingJob.perform_later(paypal)
      end
    end
  end
end