module Spree
  class PaypalController < StoreController

    def add_shipping_address
      data = JSON.parse(params[:data])
      @order = Spree::Order.find(params[:order_id]) || raise(ActiveRecord::RecordNotFound)
      paypal_order_id = data["orderID"]
      request = ::PayPalCheckoutSdk::Orders::OrdersGetRequest.new(paypal_order_id)
      begin
        response = provider.execute(request) 
        result = openstruct_to_hash(response.result)
        if @order.add_shipping_address_from_paypal(result, permitted_checkout_attributes)
          unless @order.next
            flash[:error] = @order.errors.full_messages.join("\n")
            render json: { redirect: spree.checkout_state_path(@order.state) }, status: :ok
          else
            @order.paypal_checkouts.create!(token: paypal_order_id, state: result[:status], payer_id: data["payerID"])
            render json: { redirect:  spree.checkout_state_path(@order.state) }, status: :ok
          end
        else
          render json: { redirect:  spree.checkout_state_path(@order.state) }, status: :ok
        end
      rescue PayPalHttp::HttpError => ioe
        # Something went wrong server-side
        logger.error ioe.status_code
        logger.error ioe.headers["paypal-debug-id"]
      end
    end

    def capture_order(paypal_order_id)
      request = ::PayPalCheckoutSdk::Orders::OrdersCaptureRequest::new(paypal_order_id)
      request.prefer("return=representation")
      begin
        response = provider.execute(request)
        return response
      rescue PayPalHttp::HttpError => ioe
        # Exception occured while processing the refund.
        logger.error " Status Code: #{ioe.status_code}"
        logger.error " Debug Id: #{ioe.result.debug_id}"
        logger.error " Response: #{ioe.result}"
      end
    end

    def get_order(paypal_order_id)
      request = ::PayPalCheckoutSdk::Orders::OrdersGetRequest::new(paypal_order_id)
      begin
        response = provider.execute(request)
        result = openstruct_to_hash(response.result)
        return response
      rescue PayPalHttp::HttpError => ioe
        # Exception occured while processing the refund.
        logger.error " Status Code: #{ioe.status_code}"
        logger.error " Debug Id: #{ioe.result.debug_id}"
        logger.error " Response: #{ioe.result}"
      end
    end

    def confirm
      order = current_order || raise(ActiveRecord::RecordNotFound)
      order.payments.create!({
                                 source: Spree::PaypalExpressCheckout.create({
                                                                                 token: params[:token],
                                                                                 payer_id: params[:PayerID]
                                                                             }),
                                 amount: order.total,
                                 payment_method: payment_method
                             })
      order.next
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
      @order = current_order || Spree::Order.find(params[:order_id]) || raise(ActiveRecord::RecordNotFound)
      
      if @order.paypal_checkouts.present?
        begin
          @order.payments.create!({
            source: @order.paypal_checkouts.last,
            amount: @order.total,
            payment_method: payment_method
          })
          update_paypal_order_info(@order)
          @order.next
        rescue PayPalHttp::HttpError => ioe
          # Exception occured while processing the refund.
          logger.error " Status Code: #{ioe.status_code}"
          logger.error " Debug Id: #{ioe.result.debug_id}"
          logger.error " Response: #{ioe.result}"
        end

        if @order.complete?
          flash.notice = Spree.t(:order_processed_successfully)
          flash[:order_completed] = true
          session[:order_id] = nil
          redirect_to completion_route(@order) && return
        else
          redirect_to checkout_state_path(@order.state) && return
        end
      end

      # body = {
      #   intent: 'AUTHORIZE',
      #   application_context: {
      #     return_url: confirm_paypal_url(payment_method_id: params[:payment_method_id], utm_nooverride: 1),
      #     cancel_url: cancel_paypal_url,
      #     brand_name: 'EVERYMARKET INC'
      #     # user_action: params[:paypal_action]
      #   }
      # }.merge(@order.checkout_summary)

      body = {
        intent: 'CAPTURE',
        application_context: {
          return_url: confirm_paypal_url(payment_method_id: params[:payment_method_id], utm_nooverride: 1),
          cancel_url: cancel_paypal_url,
          brand_name: 'EVERYMARKET INC',
          user_action: params[:paypal_action]
        }
      }.merge(@order.checkout_summary)

      paypal_request = ::PayPalCheckoutSdk::Orders::OrdersCreateRequest::new
      paypal_request.headers["prefer"] = "return=representation"
      paypal_request.request_body(body)
      begin
        response = provider.execute(paypal_request)
        result = openstruct_to_hash(response.result)
        if params[:paypal_action] == 'PAY_NOW'
          render json: { approve_url: get_approve_url(result[:links]) }, status: :ok
        else
          render json: { token: result[:id] }, status: :ok
        end
      rescue PayPalHttp::HttpError => ioe
        # Exception occured while processing the refund.
        logger.error " Status Code: #{ioe.status_code}"
        logger.error " Debug Id: #{ioe.result.debug_id}"
        logger.error " Response: #{ioe.result}"
      end
    end

    private

    def update_paypal_order_info(order, paypal_order_id)
      body = [{
        "op": "replace",
        "path": "/purchase_units/@reference_id=='default'/amount",
        "value": order.checkout_summary[:purchase_units].first[:amount],
        "items": order.checkout_summary[:purchase_units].first[:items]
      }]
      request = ::PayPalCheckoutSdk::Orders::OrdersPatchRequest::new(order.paypal_checkouts.last.token)
      request.request_body(body)
      response = provider.execute(request)
    end

    def openstruct_to_hash(object, hash = {})
      object.each_pair do |key, value|
        hash[key] = value.is_a?(OpenStruct) ? openstruct_to_hash(value) : value.is_a?(Array) ? array_to_hash(value) : value
      end
      hash
    end

    # Utility to convert Array of OpenStruct into Hash.
    def array_to_hash(array, hash= [])
      array.each do |item|
        x = item.is_a?(OpenStruct) ? openstruct_to_hash(item) : item.is_a?(Array) ? array_to_hash(item) : item
        hash << x
      end
      hash
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

    def delivery_route(order)
      spree.checkout_state_path('delivery')
    end

    def payment_method
      Spree::PaymentMethod.find(params[:payment_method_id])
    end
  end
end