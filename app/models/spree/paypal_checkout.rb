module Spree
  class PaypalCheckout < ActiveRecord::Base

    scope :not_sync, -> { where(tracking_sync: false) }
    scope :completed, -> { where(state: "COMPLETED") }

    has_one :payment, as: :source
    belongs_to :order

    def self.find_available_on_front_end
      Spree::PaymentMethod.available_on_front_end.find_by(type: "Spree::Gateway::PayPalCheckout")
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
