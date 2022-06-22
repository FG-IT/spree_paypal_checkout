module SpreePaypalCheckout
  class ReauthorizeAllJob < ::ApplicationJob
    queue_as :default

    def perform
      ::Spree::Payment.pending.each do |payment|
        SpreePaypalCheckout::ReauthorizationJob.perform_later(payment)
      end
    end
  end
end