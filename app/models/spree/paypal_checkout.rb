module Spree
  class PaypalCheckout < ActiveRecord::Base

    scope :not_sync, -> { where(tracking_sync: false) }
    scope :completed, -> { where(state: "COMPLETED") }

    has_one :payment, as: :source
    belongs_to :order

    def self.find_available_on_front_end
      @paypal_checkout_frontend ||= paypal_checkout_payment_methods.find {|payment_method| ['both', 'front_end'].include?(payment_method['display_on']) }
    end

    def self.find_available_on_back_end
      @paypal_checkout_backend ||= paypal_checkout_payment_methods.find {|payment_method| ['both', 'back_end'].include?(payment_method['display_on']) }
    end

    def self.paypal_checkout_payment_methods(force=false)
      cache_key = 'paypal-checkout-payment-methods'
      if force
        Rails.cache.delete(cache_key)
      end

      Rails.cache.fetch(cache_key) do
        Spree::PaymentMethod.where(type: "Spree::Gateway::PayPalCheckout", active: true).map do |payment_method|
          payment_method.serializable_hash
        end.compact
      end
    end

    def actions
      %w(capture void credit)
    end

    def can_void?(payment)
      !payment.failed? && !payment.void? && !payment.completed?
    end

    def can_capture?(payment)
      payment.pending? || payment.checkout?
    end

    def can_credit?(payment)
      payment.completed? && payment.credit_allowed > 0
    end
  end
end
