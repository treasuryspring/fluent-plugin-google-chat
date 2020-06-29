require 'uri'
require 'net/http'
require 'net/https'
require 'logger'
require 'googleauth'
require 'google/apis/chat_v1'
require_relative 'google_chat_client/error'

Chat = Google::Apis::ChatV1

module Fluent
  module GoogleChatClient
    # The base framework of google_chat client
    class Base
      SCOPE = 'https://www.googleapis.com/auth/chat.bot'.freeze

      attr_accessor :log, :debug_dev
      attr_reader   :keyfile, :https_proxy

      # @param [String] endpoint
      #
      #     (Incoming Webhook) required
      #     https://hooks.slack.com/services/XXX/XXX/XXX
      #
      #     (Slackbot) required
      #     https://xxxx.slack.com/services/hooks/slackbot?token=XXXXX
      #
      #     (Web API) optional and default to be
      #     https://slack.com/api/
      #
      # @param [String] https_proxy (optional)
      #
      #     https://proxy.foo.bar:port
      #
      def initialize(keyfile = nil, https_proxy = nil)
        self.keyfile     = keyfile    if keyfile
        self.https_proxy = https_proxy if https_proxy
        @log = Logger.new('/dev/null')
      end

      ##
      # Ensure valid credentials, either by restoring from the saved credentials
      # files or intitiating an OAuth2 authorization. If authorization is required,
      # the user's default browser will be launched to approve the request.
      #
      # @return [Google::Auth::UserRefreshCredentials] OAuth2 credentials
      def authorize
        credentials = Google::Auth::ServiceAccountCredentials.make_creds(
            json_key_io: File.open(self.keyfile),
            scope: SCOPE
        )
        credentials
      end

      def keyfile=(keyfile)
        @keyfile    = keyfile
      end

      def https_proxy=(https_proxy)
        @https_proxy = URI.parse(https_proxy)
        @proxy_class = Net::HTTP.Proxy(@https_proxy.host, @https_proxy.port)
      end

      def proxy_class
        @proxy_class ||= Net::HTTP
      end

      def post(params)
        chat = Chat::HangoutsChatService.new
        chat.authorization = authorize
        message = Chat::Message.new
        message.text = params.text

        chat.create_space_message(
            'spaces/%s' % params.space,
            message
        )
      end
    end

    # GoogleChat client
    class WebApi < Base
      # Sends a message to a space.
      def post_message(params = {})
        log.info { "out_google_chat: post_message #{params}" }
        post(params)
      end

      private
    end
  end
end
