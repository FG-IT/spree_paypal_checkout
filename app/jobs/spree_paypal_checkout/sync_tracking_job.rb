module SpreePaypalCheckout
  class SyncTrackingJob < ::ApplicationJob
    queue_as :default

    def perform(paypal)
      paypal.order.sync_tracking_to_paypal_checkout(paypal.payment)
    end
  end
end