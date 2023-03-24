require_relative 'google_chat_client'

module Fluent
  class GoogleChatOutput < Fluent::BufferedOutput
    Fluent::Plugin.register_output('buffered_google_chat', self) # old version compatiblity
    Fluent::Plugin.register_output('google_chat', self)

    # For fluentd v0.12.16 or earlier
    class << self
      unless method_defined?(:desc)
        def desc(description)
        end
      end
    end

    include SetTimeKeyMixin
    include SetTagKeyMixin

    config_set_default :include_time_key, true
    config_set_default :include_tag_key, true

    desc <<-DESC
Incoming Webhook URI (Required for Incoming Webhook mode).
See: https://api.slack.com/incoming-webhooks
DESC
    config_param :keyfile,                :string, default: nil
    desc "Private key file."
    config_param :https_proxy,          :string, default: nil

    desc "space to send messages (room id)."
    config_param :space,              :string, default: nil
    desc <<-DESC
Keys used to format space.
%s will be replaced with value specified by space_keys if this option is used.
DESC
    config_param :space_keys,         default: nil do |val|
      val.split(',')
    end
    desc <<-DESC
Message format.
%s will be replaced with value specified by message_keys.
DESC
    config_param :message,              :string, default: nil
    desc "Keys used to format messages."
    config_param :message_keys,         default: nil do |val|
      val.split(',')
    end

    desc "Include messages to the fallback attributes"
    config_param :verbose_fallback,     :bool,   default: false

    # for test
    attr_reader :google_chat, :time_format, :localtime, :timef, :mrkdwn_in, :post_message_opts

    def initialize
      super
      require 'uri'
    end

    def configure(conf)
      conf['time_format'] ||= '%H:%M:%S' # old version compatiblity
      conf['localtime'] ||= true unless conf['utc']

      super

      if @space
        @space = URI::Parser.new.unescape(@space)
      else
        raise Fluent::ConfigError.new("`space` is required")
      end

      if @keyfile
        if @keyfile.empty?
          raise Fluent::ConfigError.new("`keyfile` is an empty string")
        end
        if @keyfile.nil?
          raise Fluent::ConfigError.new("`keyfile` parameter required for Google Chat")
        end
        @google_chat = Fluent::GoogleChatClient::WebApi.new(@keyfile)
      else
        raise Fluent::ConfigError.new("`keyfile` is required")
      end
      @google_chat.log = log
      @google_chat.debug_dev = log.out if log.level <= Fluent::Log::LEVEL_TRACE

      if @https_proxy
        @google_chat.https_proxy = @https_proxy
      end

      @message      ||= '%s'
      @message_keys ||= %w[message]
      begin
        @message % (['1'] * @message_keys.length)
      rescue ArgumentError
        raise Fluent::ConfigError, "string specifier '%s' for `message`  and `message_keys` specification mismatch"
      end
      if @space_keys
        begin
          @space % (['1'] * @space_keys.length)
        rescue ArgumentError
          raise Fluent::ConfigError, "string specifier '%s' for `space` and `space_keys` specification mismatch"
        end
      end
    end

    def format(tag, time, record)
      [tag, time, record].to_msgpack
    end

    def write(chunk)
      begin
        payloads = build_payloads(chunk)
        payloads.each {|payload| @google_chat.post_message(payload) }
      rescue Timeout::Error => e
        log.warn "out_google_chat:", :error => e.to_s, :error_class => e.class.to_s
        raise e # let Fluentd retry
      rescue => e
        log.error "out_google_chat:", :error => e.to_s, :error_class => e.class.to_s
        log.warn_backtrace e.backtrace
        # discard. @todo: add more retriable errors
      end
    end

    private

    def build_payloads(chunk)
      build_plain_payloads(chunk)
    end

    Field = Struct.new("Field", :title, :value)
    # ruby 1.9.x does not provide #to_h
    Field.send(:define_method, :to_h) { {title: title, value: value} }

    def build_plain_payloads(chunk)
      messages = {}
      chunk.msgpack_each do |tag, time, record|
        space = build_space(record)
        messages[space] ||= ''
        messages[space] << "#{build_message(record)}\n"
      end
      messages.map do |space, text|
        msg = {text: text}
        msg.merge!(space: space) if space
      end
    end

    def build_message(record)
      values = fetch_keys(record, @message_keys)
      @message % values
    end

    def build_space(record)
      return nil if @space.nil?
      return @space unless @space_keys

      values = fetch_keys(record, @space_keys)
      @space % values
    end

    def fetch_keys(record, keys)
      Array(keys).map do |key|
        begin
          record.fetch(key).to_s
        rescue KeyError
          log.warn "out_google_chat: the specified key '#{key}' not found in record. [#{record}]"
          ''
        end
      end
    end
  end
end
