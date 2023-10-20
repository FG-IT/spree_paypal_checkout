module PaypalServices
  class Checkout

    def initialize(order, provider)
      @order = order
      @provider = provider
    end

    def paypal_order_valid?
      if @order.paypal_checkout.order_valid_time.present?
        Time.now < @order.paypal_checkout.order_valid_time ? true : false
      else
        false
      end
      # begin
      #   request = ::PayPalCheckoutSdk::Orders::OrdersGetRequest::new(@order.paypal_checkout.token)
      #   result = ::PaypalServices::Request.request_paypal(@provider, request)
      #   return true
      # rescue PayPalHttp::HttpError => ioe
      #   return false
      # end
    end

    def update_paypal_order
      request = ::PayPalCheckoutSdk::Orders::OrdersPatchRequest::new(@order.paypal_checkout.token)
      result = ::PaypalServices::Request.request_paypal(@provider, request, paypal_order_info)
    end

    def line_item(item)
      promo_total = @order.promo_total
      item_total = @order.item_total
      this_item_total = item.pre_tax_amount

      shipping_tax = @order.shipments.sum(:adjustment_total)

      this_shipping_tax = shipping_tax * this_item_total / item_total
      {
        "name" => item.product.name,
        # "sku" => item.variant.sku,
        # "url" => product_url(item.product),
        "quantity" => item.quantity,
        "unit_amount" => {
          currency_code: @order.currency,
          value: "%.2f" % item.price
        },
        "tax" => {
          currency_code: @order.currency,
          value: "%.2f" % ((item.additional_tax_total + this_shipping_tax) / item.quantity)
        }
      }

    end

    def random_str
      (0...4).map { (65 + rand(26)).chr }.join
    end

    def paypal_order_request_info

      items = @order.line_items.map(&method(:line_item))
      reference = "#{@order.number}-#{random_str}"
      purchase_unit = {
        reference_id: reference,
        amount: {
          currency_code: @order.currency,
          value: "%.2f" % @order.total,
          breakdown: {
            item_total: {
              currency_code: @order.currency,
              value: "%.2f" % @order.item_total
            },
            shipping: {
              currency_code: @order.currency,
              value: "%.2f" % @order.shipment_total
            },
            tax_total: {
              currency_code: @order.currency,
              value: "%.2f" % @order.additional_tax_total
            },
            discount: {
              currency_code: @order.currency,
              value: "%.2f" % (0 - @order.promo_total)
            }
          }
        },
        items: items
      }

      if @order.ship_address.present?
        shipping = {
          name: {
            full_name: @order.ship_address.firstname + " " + @order.ship_address.lastname
          },
          address: {
            address_line_1: @order.ship_address.address1,
            address_line_2: @order.ship_address.address2,
            admin_area_2: @order.ship_address.city,
            admin_area_1: @order.ship_address&.state&.name,
            postal_code: @order.ship_address.zipcode,
            country_code: @order.ship_address.country.iso
          }
        }
        purchase_unit = purchase_unit.merge(shipping: shipping)
      end
      request_info = { purchase_units: [purchase_unit] }
      if @order.email.present?
        payer = {
          email_address: @order.email
        }
        request_info = request_info.merge(payer: payer)
      end
      request_info
    end

    def paypal_order_info
      paypal_order_info = [{
                             "op": "replace",
                             "path": "/purchase_units/@reference_id=='default'/amount",
                             "value": paypal_order_request_info[:purchase_units].first[:amount]
                           }]

      if paypal_order_request_info[:purchase_units].first[:shipping].present?

      end
      if paypal_order_request_info[:purchase_units].first[:shipping].present?
        paypal_order_info = paypal_order_info + [
          {
            "op": "replace",
            "path": "/purchase_units/@reference_id=='default'/shipping/address",
            "value": paypal_order_request_info[:purchase_units].first[:shipping][:address]
          },
          {
            "op": "replace",
            "path": "/purchase_units/@reference_id=='default'/shipping/name",
            "value": paypal_order_request_info[:purchase_units].first[:shipping][:name]
          }]
      end
      paypal_order_info
    end

    def add_paypal_checkout_record(result)
      if @order.paypal_checkout.present?
        @order.paypal_checkout.update!(token: result[:id], state: result[:status], payer_id: result[:payer][:payer_id], order_valid_time: Time.now + 2 * 60 * 60)
      else
        @order.create_paypal_checkout(token: result[:id], state: result[:status], payer_id: result[:payer][:payer_id], order_valid_time: Time.now + 2 * 60 * 60)
      end
    end

    def add_shipping_address_from_paypal(result, permitted_attributes)
      if @order.ship_address.blank?
        address = result[:purchase_units].first[:shipping][:address]
        name = result[:purchase_units].first[:shipping][:name][:full_name]
        country_id = ::Spree::Country.find_by(iso: address[:country_code]).id
        state_id = ::Spree::State.where({ abbr: address[:admin_area_1], country_id: country_id }).first&.id

        address_params = {
          firstname: name.split.first,
          lastname: name.split.last,
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
        @order.update_from_params(_params, permitted_attributes)
      end
      @order.update_column(:state, "address")
      add_paypal_checkout_record(result)
      @order.next
    end

    def paypal_order_params(intent, return_url, cancel_url, brand_name, user_action)
      paypal_order_params = {
        intent: intent,
        application_context: {
          return_url: return_url,
          cancel_url: cancel_url,
          brand_name: brand_name,
          user_action: user_action,
          shipping_preference: @order.ship_address.present? ? :SET_PROVIDED_ADDRESS : :GET_FROM_FILE
        }
      }
      paypal_order_params.merge(paypal_order_request_info)
    end

    def complete_with_paypal_checkout(token, payer_id, payment_method)
      paypal_checkout = ::Spree::PaypalCheckout.find_by(token: token, payer_id: payer_id, order_id: @order.id)
      if paypal_checkout.blank?
        paypal_checkout = @order.create_paypal_checkout({ token: token, payer_id: payer_id, order_valid_time: Time.now + 3.days })
      end
      @order.payments.create!({
                                source: paypal_checkout,
                                amount: @order.total,
                                payment_method: payment_method
                              })
      @order.next
    end

    def complete_with_paypal_express_payment(payment_method)
      @order.payments.create!({
                                source: @order.paypal_checkout,
                                amount: @order.total,
                                payment_method: payment_method
                              })
      @order.next
      @order.paypal_checkout.update(order_valid_time: Time.now + 3.days)
    end

    AES_KEY = "\x8BF\x9A\xC0\xDC\x03\x95iU\xFF\xA0:\xCB\xF9\xBB\x12"

    class << self

      def aes_encrypt(key, encrypted_string)
        aes = OpenSSL::Cipher::Cipher.new("AES-128-ECB")
        aes.encrypt
        aes.key = Digest::MD5.hexdigest(key).first(16)
        txt = aes.update(encrypted_string) << aes.final
        txt.unpack('H*')[0].upcase
      end

      def aes_dicrypt(key, dicrypted_string)
        aes = OpenSSL::Cipher::Cipher.new("AES-128-ECB")
        aes.decrypt
        aes.key = Digest::MD5.hexdigest(key).first(16)
        aes.update([dicrypted_string].pack('H*')) << aes.final
      end
    end
  end
end