module Spree
  class PaypalController < StoreController

    # Setting up and Returns PayPal SDK environment with PayPal Access credentials.
    # For demo purpose, we are using SandboxEnvironment. In production this will be
    # LiveEnvironment.
    def environment
      client_id = ENV['PAYPAL_CLIENT_ID']
      client_secret = ENV['PAYPAL_CLIENT_SECRET']
      ::PayPal::SandboxEnvironment.new(client_id, client_secret)
      # PayPal::LiveEnvironment.new(client_id, client_secret)
    end

    def client
      @client ||= ::PayPal::PayPalHttpClient.new(self.environment)
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

    def add_shipping_address
      current_order = Spree::Order.find(params[:order_id])
      @order = current_order || raise(ActiveRecord::RecordNotFound)
      paypal_order_id = params[:paypal_order_id]
      # Creating Access Token for Sandbox
      binding.pry
      request = ::PayPalCheckoutSdk::Orders::OrdersGetRequest.new(paypal_order_id)
      begin
        # Call API with your client and get a response for your call
        response = client.execute(request) 
        # If call returns body in response, you can get the deserialized version from the result attribute of the response
        if @order.add_shipping_address_from_paypal(response, permitted_checkout_attributes)
          unless @order.next
            flash[:error] = @order.errors.full_messages.join("\n")
            render json: { redirect:  completion_route }, status: :ok
          end
          if @order.completed?
            @current_order = nil
            flash['order_completed'] = true
            render json: { redirect:  completion_route }, status: :ok
          else
            render json: { redirect:  spree.checkout_state_path(@order.state) }, status: :ok
          end
        else
          render json: { redirect:  spree.checkout_state_path(@order.state) }, status: :ok
        end

      rescue PayPalHttp::HttpError => ioe
        # Something went wrong server-side
        puts ioe.status_code
        puts ioe.headers["paypal-debug-id"]
      end
    end

    def patch_order(order_id, paypal_order_id)

      current_order = Spree::Order.find(order_id)
      @order = current_order || raise(ActiveRecord::RecordNotFound)

      body = [{
        "op": "replace",
        "path": "/purchase_units/@reference_id=='default'/amount",
        "value": @order.checkout_summary[:purchase_units].first[:amount],
        "items": @order.checkout_summary[:purchase_units].first[:items]
      }]

      request = ::PayPalCheckoutSdk::Orders::OrdersPatchRequest::new(paypal_order_id)
      request.request_body(body)
      response = client.execute(request)
      return response
    end

    def capture_order(paypal_order_id)
      request = ::PayPalCheckoutSdk::Orders::OrdersCaptureRequest::new(paypal_order_id)
      request.prefer("return=representation")
      begin
        response = client.execute(request)
        return response
      rescue PayPalHttp::HttpError => ioe
        # Exception occured while processing the refund.
        puts " Status Code: #{ioe.status_code}"
        puts " Debug Id: #{ioe.result.debug_id}"
        puts " Response: #{ioe.result}"
      end
    end

    def get_order(paypal_order_id)
      request = ::PayPalCheckoutSdk::Orders::OrdersGetRequest::new(paypal_order_id)
      begin
        response = client.execute(request)
        result = openstruct_to_hash(response.result)
        return response
      rescue PayPalHttp::HttpError => ioe
        # Exception occured while processing the refund.
        puts " Status Code: #{ioe.status_code}"
        puts " Debug Id: #{ioe.result.debug_id}"
        puts " Response: #{ioe.result}"
      end
    end

    def cancel
      flash[:notice] = Spree.t('flash.cancel', scope: 'paypal')
      order = current_order || raise(ActiveRecord::RecordNotFound)
      redirect_to checkout_state_path(order.state, paypal_cancel_token: params[:token])
    end

    def create_paypal_order
      current_order = Spree::Order.find(params[:order_id])
      @order = current_order || raise(ActiveRecord::RecordNotFound)
      body = @order.checkout_summary
      body = {
        intent: 'CAPTURE'
      }.merge(@order.checkout_summary)
      request = ::PayPalCheckoutSdk::Orders::OrdersCreateRequest::new
      request.headers["prefer"] = "return=representation"
      request.request_body(body)
      begin
        response = client.execute(request)
        result = openstruct_to_hash(response.result)
        render json: { token: result[:id] }, status: :ok
      rescue PayPalHttp::HttpError => ioe
        # Exception occured while processing the refund.
        puts " Status Code: #{ioe.status_code}"
        puts " Debug Id: #{ioe.result.debug_id}"
        puts " Response: #{ioe.result}"
      end
    end

    private

    def line_item(item)
      {
        Name: item.name,
        Number: item.sku,
        Quantity: item.quantity,
        Amount: {
            currencyID: item.currency,
            value: item.price
        },
        ItemCategory: "Physical"
      }
    end

    def provider
      payment_method.provider
    end

    def payment_method
      # Spree::PaymentMethod.find(params[:payment_method_id])
      Spree::PaymentMethod.find(8)
    end
  end
end