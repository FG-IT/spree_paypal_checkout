module Spree
  class PaypalCheckoutController < StoreController

    def add_shipping_address
      order = Spree::Order.find(params[:order_id]) || raise(ActiveRecord::RecordNotFound)
      paypal_order_id = params[:data]["orderID"]
      request = ::PayPalCheckoutSdk::Orders::OrdersGetRequest.new(paypal_order_id)
      binding.pry
      paypal = paypal_checkout(order, provider)
      result = ::PaypalServices::Request.request_paypal(provider, request)
      if paypal.add_shipping_address_from_paypal(result, permitted_checkout_attributes)
        render json: { redirect:  spree.checkout_state_path(order.state) }, status: :ok
      else
        flash[:error] = order.errors.full_messages.join("\n")
        render json: { redirect:  spree.checkout_state_path(order.state) }, status: :ok
      end
    end

    def capture_order(paypal_order_id)
      request = ::PayPalCheckoutSdk::Orders::OrdersCaptureRequest::new(paypal_order_id)
      result = ::PaypalServices::Request.request_paypal(provider, request, body, "return=representation")
    end

    def confirm
      order = current_order || raise(ActiveRecord::RecordNotFound)
      paypal =paypal_checkout(order, provider)
      paypal.complete_with_paypal_checkout(params[:token], params[:PayerID], payment_method)

      if order.complete?
        flash.notice = Spree.t(:order_processed_successfully)
        flash[:order_completed] = true
        session[:order_id] = nil
        redirect_to completion_route(order)
      else
        redirect_to checkout_state_path(order.state)
      end
    end

    def cancel
      flash[:notice] = Spree.t('flash.cancel', scope: 'paypal')
      order = current_order || raise(ActiveRecord::RecordNotFound)
      redirect_to checkout_state_path(order.state, paypal_cancel_token: params[:token])
    end

    def create_paypal_order
      order = current_order || Spree::Order.find(params[:order_id]) || raise(ActiveRecord::RecordNotFound)
      paypal =paypal_checkout(order, provider)
      if order.paypal_checkout.present? && paypal.valid?(order.paypal_checkout.token)
        paypal.update_paypal_order
        if params[:paypal_action] == 'PAY_NOW'
          order.complete_with_paypal_express_payment(payment_method)
          if order.complete?
            flash.notice = Spree.t(:order_processed_successfully)
            flash[:order_completed] = true
            session[:order_id] = nil
            render json: { redirect: completion_route(order) }, status: :ok
          else
            render json: { redirect: checkout_state_path(order.state) }, status: :ok
          end
        else
          render json: { token: order.paypal_checkout.token }, status: :ok
        end
      else
        body = paypal.paypal_order_params('CAPTURE', confirm_paypal_checkout_url(payment_method_id: params[:payment_method_id], utm_nooverride: 1), cancel_paypal_checkout_url, 'EVERYMARKET INC', params[:paypal_action])
        request = ::PayPalCheckoutSdk::Orders::OrdersCreateRequest::new
        result = ::PaypalServices::Request.request_paypal(provider, request, body, "return=representation")
        if params[:paypal_action] == 'PAY_NOW'
          render json: { redirect: get_approve_url(result[:links]) }, status: :ok
        else
          render json: { token: result[:id] }, status: :ok
        end
      end
    end

    private

    def paypal_checkout(order, provider)
      @paypal_checkout ||= ::PaypalServices::Checkout.new(order, provider)
    end

    def get_approve_url(links)
      approve_link = links.select do |link|
        link[:rel] == "approve"
      end
      approve_link.first[:href]
    end

    def provider
      payment_method.provider
    end

    def completion_route(order)
      order_path(order)
    end

    def payment_method
      Spree::PaymentMethod.find(params[:payment_method_id])
    end
  end
end