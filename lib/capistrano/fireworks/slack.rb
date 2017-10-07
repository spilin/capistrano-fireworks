module Capistrano
  module Fireworks
    class SlackPost
      def initialize(hook_url: , attributes: )
        @uri, @attributes = URI(hook_url), attributes
      end

      def call
        message = compose_message
        post(message)
      end

      private

      def compose_message
        "<#{@attributes[:commit_url]}|#{@attributes[:branch]}(#{@attributes[:commit]} - #{@attributes[:subject]})> deployed to `#{@attributes[:name]}` by #{@attributes[:username]}!"
      end

      def post(text)
        req = Net::HTTP::Post.new(@uri)
        req.content_type = 'application/json'
        req.body = JSON.dump(text: text)
        http = Net::HTTP.new(@uri.hostname, @uri.port)
        http.use_ssl = true
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
        res = http.request(req)
        puts res.body
      end
    end
  end
end
