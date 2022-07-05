require 'cgi'

module PayPalCheckoutSdk

  class TrackingUploadRequest
    attr_accessor :path, :body, :headers, :verb

    def initialize()
      @headers = {}
      @body = nil
      @verb = "POST"

      @path = "/v1/shipping/trackers-batch"
      @headers["Content-Type"] = "application/json"
    end

    def request_body(tracker)
      @body = tracker
    end

  end
end
