require 'cgi'

module PayPalCheckoutSdk

  class TrackingUpdateRequest
    attr_accessor :path, :body, :headers, :verb

    def initialize(transaction_id, tracking_number)
      @headers = {}
      @body = nil
      @verb = "PUT"
      @path = "/v1/shipping/trackers/{id}"

      @path = @path.gsub("{id}", CGI::escape(transaction_id.to_s + "-" + tracking_number.to_s))
      @headers["Content-Type"] = "application/json"
    end

    def request_body(tracker)
      @body = tracker
    end

  end
end
