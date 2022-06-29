module Paypal
  module ShipmentDecorator
    def update_attributes_and_order(params = {})
      if update params
        if params.key? :selected_shipping_rate_id
          # Changing the selected Shipping Rate won't update the cost (for now)
          # so we persist the Shipment#cost before calculating order shipment
          # total and updating payment state (given a change in shipment cost
          # might change the Order#payment_state)
          update_amounts

          order.updater.update_shipment_total
          order.updater.update_payment_state

          # Update shipment state only after order total is updated because it
          # (via Order#paid?) affects the shipment state (YAY)
          update_columns(
            state: determine_state(order),
            updated_at: Time.current
          )

          # And then it's time to update shipment states and finally persist
          # order changes
          order.updater.update_shipment_state
          order.updater.persist_totals
        end

        if params[:tracking].present? && params[:carrier].present?
          if !shipped? && (state !="canceled")
            ship!
            update_columns(shipped_at: Time.now)
            update!(order)
          end 
          sync_tracking_to_payment(params[:tracking], params[:carrier])
        end

        true
      end
    end

    def sync_tracking_to_payment(tracking_number, carrier, status="SHIPPED")
      self.order.payments.each do |payment|
        if payment.payment_method.preferred_need_tracking
          response = payment.payment_method.upload_tracking(payment.source.transaction_id, tracking_number, status, carrier)
        end
      end
    end
  end
end

::Spree::Shipment.prepend Paypal::ShipmentDecorator
