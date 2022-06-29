module Spree
  class PaypalCheckout < ActiveRecord::Base

    def self.sync_tracking(tracking_number, carrier, status="SHIPPED")
      self.order.payments.each do |payment|
        if payment.payment_method.preferred_need_tracking
          response = payment.payment_method.upload_tracking(payment.source.transaction_id, tracking_number, status, carrier)
        end
      end
    end

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
