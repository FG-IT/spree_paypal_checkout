require 'cgi'

module PayPalCheckoutSdk

  class TrackingShowRequest
    attr_accessor :path, :body, :headers, :verb

    def initialize(transaction_id, tracking_number)
      @headers = {}
      @body = nil
      @verb = "GET"
      @path = "/v1/shipping/trackers/{id}"

      @path = @path.gsub("{id}", CGI::escape(transaction_id.to_s + "-" + tracking_number.to_s))
      @headers["Content-Type"] = "application/json"
    end
  end
end
