require_relative '../test_helper'
require 'fluent/plugin/google_chat_client'
require 'time'
require 'dotenv'
require 'webrick'
require 'webrick/httpproxy'

# HOW TO RUN
#
# Create .env file with contents as:
#
#     WEBHOOK_URL=https://hooks.slack.com/services/XXXX/YYYY/ZZZZ
#     SLACKBOt_URL=https://xxxx.slack.com/services/hooks/slackbot?token=XXXX
#     SLACK_API_TOKEN=XXXXX
#
Dotenv.load
if ENV['WEBHOOK_URL'] and ENV['SLACKBOT_URL'] and ENV['SLACK_API_TOKEN']
  class TestProxyServer
    def initialize
      @proxy = WEBrick::HTTPProxyServer.new(
        :BindAddress => '127.0.0.1',
        :Port => unused_port,
      )
    end

    def proxy_url
      "https://127.0.0.1:#{unused_port}"
    end

    def start
      @thread = Thread.new do
        @proxy.start
      end
    end

    def shutdown
      @proxy.shutdown
    end

    def unused_port
      return @unused_port if @unused_port
      s = TCPServer.open(0)
      port = s.addr[1]
      s.close
      @unused_port = port
    end
  end

  class GoogleChatClientTest < Test::Unit::TestCase
    class << self
      attr_reader :proxy

      def startup
        @proxy = TestProxyServer.new.tap {|proxy| proxy.start }
      end

      def shutdown
        @proxy.shutdown
      end
    end

    def setup
      super
      @api            = Fluent::GoogleChatClient::WebApi.new

      proxy_url       = self.class.proxy.proxy_url
      @api_proxy      = Fluent::GoogleChatClient::WebApi.new(nil, proxy_url)
    end

    def default_payload(client)
      {
          space:   'space',
          keyfile: 'xxxx.json'
      }
    end

    def valid_utf8_encoded_string
      "space \xE3\x82\xA4\xE3\x83\xB3\xE3\x82\xB9\xE3\x83\x88\xE3\x83\xBC\xE3\x83\xAB\n"
    end

    def invalid_ascii8bit_encoded_utf8_string
      str = "space \xE3\x82\xA4\xE3\x83\xB3\xE3\x82\xB9\xE3\x83\x88\xE3\x83\xBC\xE3\x83\xAB\x81\n"
      str.force_encoding(Encoding::ASCII_8BIT)
    end

    # Notification via Highlight Words works with only Slackbot with plain text payload
    # NOTE: Please add `sowawa1` to Highlight Words
    def test_post_message_plain_payload
      [@api].each do |gc|
        assert_nothing_raised do
          gc.post_message(default_payload(gc).merge({
            text: "treasuryspring\n",
          }))
        end
      end
    end

    def test_post_via_proxy
      [@api_proxy].each do |gc|
        assert_nothing_raised do
          gc.post_message(default_payload(gc).merge({
            text: "treasuryspring\n"
          }))
        end
      end
    end

    # IncomingWebhook posts "space インストール"
    def test_post_message_utf8_encoded_text
      [@incoming].each do |gc|
        assert_nothing_raised do
          gc.post_message(default_payload(gc).merge({
            text: valid_utf8_encoded_string,
          }))
        end
      end
    end

    # IncomingWebhook posts "space インストール?"
    def test_post_message_ascii8bit_encoded_utf8_text
      [@incoming].each do |gc|
        assert_nothing_raised do
          gc.post_message(default_payload(gc).merge({
            text: invalid_ascii8bit_encoded_utf8_string,
          }))
        end
      end
    end
  end
end
