module PaypalServices
  class Response
    attr_reader :result, :authorization, :avs_result, :cvv_result

    
    def initialize(response)
      @response = response
      @result = openstruct_to_hash(response.result) if response.result.present?
    end

    def update_authorization(id)
      @authorization = id
      @avs_result = ::ActiveMerchant::Billing::AVSResult.new(nil).to_hash
      @cvv_result = ::ActiveMerchant::Billing::CVVResult.new(nil).to_hash
    end

    def success?
      if @response.status_code >= 200 and @response.status_code < 300
        true
      else
        false
      end
    end

    def to_s
      errors.map(&:long_message).join(" ")
    end

    private

    def openstruct_to_hash(object, hash = {})
      object.each_pair do |key, value|
        hash[key] = value.is_a?(OpenStruct) ? openstruct_to_hash(value) : value.is_a?(Array) ? array_to_hash(value) : value
      end
      hash
    end

    def array_to_hash(array, hash= [])
      array.each do |item|
        x = item.is_a?(OpenStruct) ? openstruct_to_hash(item) : item.is_a?(Array) ? array_to_hash(item) : item
        hash << x
      end
      hash
    end
    
  end
end