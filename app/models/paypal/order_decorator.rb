module Paypal
  module OrderDecorator

    def self.prepended(base)
      base.has_many :paypal_checkouts, class_name: "Spree::PaypalCheckout"
    end

    def checkout_summary
      items = []
      self.line_items.each do |item|
        items << {
          name: item.name.truncate(30),
          unit_amount: {
            currency_code: item.currency,
            value: item.price
          },
          quantity: item.quantity
        }
      end

      { purchase_units: 
        [{
          amount: {
            currency_code: self.currency,
            value: self.total,
            breakdown: {
              item_total: {  
                currency_code: self.currency,
                value: self.item_total
              },
              tax_total: {
                currency_code: self.currency,
                value: self.adjustment_total
              },
              shipping: {
                currency_code: self.currency,
                value: self.shipment_total
              }
            }
          },
          items: items
        }] 
      }
    end

    def add_shipping_address_from_paypal(result, permitted_attributes)
      address = result[:purchase_units].first[:shipping][:address]
      name = result[:purchase_units].first[:shipping][:name]
      country_id = ::Spree::Country.find_by(iso: address[:country_code]).id
      state_id = ::Spree::State.where({abbr: address[:admin_area_1], country_id: country_id}).first.id

      address_params = {
        firstname: result[:payer][:name][:given_name], 
        lastname: result[:payer][:name][:surname], 
        address1: address[:address_line_1],
        address2: address[:address_line_2],
        city: address[:admin_area_2], 
        state_id: state_id.to_s, 
        zipcode: address[:postal_code], 
        country_id: country_id.to_s, 
        phone: address[:phone]
      }

      customer_info_params = { 
        email: result[:payer][:email_address], 
        bill_address_attributes: address_params,
        ship_address_attributes: address_params
      }

      _params = ActionController::Parameters.new({
        order: {
          email: result[:payer][:email_address], 
          bill_address_attributes: address_params,
          use_billing: "1"
        },
        save_user_address: true
      })
      update_column(:state, "address")
      update_from_params(_params, permitted_attributes)
    end

    def paypal_express_payment
      payments.from_paypal_express
    end

    def payment_method
      Spree::PaymentMethod.find(params[:payment_method_id])
    end

    def client
      payment_method.provider_express
    end

    def payment_request
      # items = self.line_items.map(&method(:line_item))

      # additional_adjustments = self.all_adjustments.additional
      # tax_adjustments = additional_adjustments.tax
      # shipping_adjustments = additional_adjustments.shipping

      # additional_adjustments.eligible.each do |adjustment|
      #   # Because PayPal doesn't accept $0 items at all. See #10
      #   # https://cms.paypal.com/uk/cgi-bin/?cmd=_render-content&content_ID=developer/e_howto_api_ECCustomizing
      #   # "It can be a positive or negative value but not zero."
      #   next if adjustment.amount.zero?
      #   next if tax_adjustments.include?(adjustment) || shipping_adjustments.include?(adjustment)

      #   items << {
      #     Name: adjustment.label,
      #     Quantity: 1,
      #     amount: {
      #       currency_code: self.currency,
      #       value: adjustment.amount
      #     }
      #   }
      # end

      # request_attributes = {
      #   amount: self.total,
      #   description: DESCRIPTION[:instant],
      #   items: items
      # }
      express_checkout_request_details self.line_items
    end

    def get_customer_info(order_id)
      request = PayPalCheckoutSdk::Orders::OrdersGetRequest.new(order_id)
      response = client.execute(request)
    end


    def create_payment

      # Creating Access Token for Sandbox
      client_id = "AUw8RvSkGWFJsNh4rBcCkztSW2ktewEGHWnOzYAB3OhbHzfdYUSBJHIY-Bv65r4Y7Riyj_qaQHt_4Zj0"
      client_secret = "EKXPsGaFmkeav0P3jAEICnYn8p00fFMSuhcHZ6FRrI25Pl2wvnMme8WRy0AMITjJeSVoLi7Y7dCVX8uM"
      environment = ::PayPal::SandboxEnvironment.new(client_id, client_secret)
      client = ::PayPal::PayPalHttpClient.new(environment)

      request = PayPalCheckoutSdk::Orders::OrdersCreateRequest::new
      request.request_body({
                              intent: "CAPTURE",
                              purchase_units: [
                                  {
                                      amount: {
                                          currency_code: "USD",
                                          value: "101.00"
                                      }
                                  }
                              ]
                            })


      

      begin
        # Call API with your client and get a response for your call
        response = client.execute(request)

        order.payments.create!({
          source: Spree::PaypalCheckout.create({
                                                          token: params[:orderID],
                                                          payer_id: params[:PayerID]
                                                      }),
          amount: order.total,
          payment_method: payment_method
      })
        # If call returns body in response, you can get the deserialized version from the result attribute of the response
        order = result
        puts order
      rescue PayPalHttp::HttpError => ioe
        # Something went wrong server-side
        puts ioe.status_code
        puts ioe.headers["debug_id"]
      end

      items = self.line_items.map(&method(:line_item))

      additional_adjustments = self.all_adjustments.additional
      tax_adjustments = additional_adjustments.tax
      shipping_adjustments = additional_adjustments.shipping

      additional_adjustments.eligible.each do |adjustment|
        # Because PayPal doesn't accept $0 items at all. See #10
        # https://cms.paypal.com/uk/cgi-bin/?cmd=_render-content&content_ID=developer/e_howto_api_ECCustomizing
        # "It can be a positive or negative value but not zero."
        next if adjustment.amount.zero?
        next if tax_adjustments.include?(adjustment) || shipping_adjustments.include?(adjustment)

        items << {
            Name: adjustment.label,
            Quantity: 1,
            Amount: {
                currencyID: self.currency,
                value: adjustment.amount
            }
        }
      end

      paypal_express_payment = ::PayPal::SDK::REST::Payment.new({
        intent:  "sale",
        payer:  { payment_method: "paypal" },
        redirect_urls: {
          return_url: "/",
          cancel_url: "/" 
        },
        transactions:  [{
          item_list: {
            items: items
          },
          amount:  {
            total: self.total,
            currency: self.currency
          },
          description:  "Payment for: #{self.number}"
        }]
      })
      if paypal_express_payment.create
        self.payments.create!({
          source: Spree::PaypalCheckout.create({
                                                          token: paypal_express_payment.token,
                                                          state: "pending"
                                                      }),
          amount: self.total,
          payment_method: Spree::PaymentMethod.find(8)
        })
        return paypal_express_payment.token
      end
    end

    def execute_paypal_express_payment(payment_id:, payer_id:, token:)
      paypal_express_checkout = Spree::PaypalCheckout.find_by(token: token)
      paypal_express_checkout.update_columns(payer_id: payer_id, transaction_id: payment_id)
      # payment = ::PayPal::SDK::REST::Payment.find(payment_id)
      # if payment.execute( payer_id: payer_id )
      #   self.set_paypal_executed
      #   return self.save
      # end
    end

    def set_paypal_executed
      self.status = Order.statuses[:paypal_executed]
    end

    private

    def express_checkout_request_details items
      purchase_units = []
      items.each do |item|
        purchase_units << { 
          amount: {
            value: item.quantity * item.price
          }
        }
      end
      purchase_units
    end

    def line_item(item)
      {
          Name: item.product.name,
          Number: item.variant.sku,
          Quantity: item.quantity,
          Amount: {
              currencyID: item.order.currency,
              value: item.price
          },
          ItemCategory: "Physical"
      }
    end
  end
end

::Spree::Order.prepend Paypal::OrderDecorator
