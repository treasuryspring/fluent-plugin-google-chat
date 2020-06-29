require_relative '../test_helper'
require 'fluent/plugin/out_google_chat'
require 'time'

class GoogleChatOutputTest < Test::Unit::TestCase

  def setup
    super
    Fluent::Test.setup
  end

  CONFIG = %[
    space space
  ]

  def default_payload
    {
        space:    'space'
    }
  end

  def create_driver(conf = CONFIG)
    Fluent::Test::BufferedOutputTestDriver.new(Fluent::GoogleChatOutput).configure(conf)
  end

  # old version compatibility with v0.4.0"
  def test_old_config
    # default check
    d = create_driver
    assert_equal true, d.instance.localtime

    assert_nothing_raised do
      create_driver(CONFIG + %[api_key testtoken])
    end

    # incoming webhook endpoint was changed. team option should be ignored
    assert_nothing_raised do
      create_driver(CONFIG + %[team treasuryspring])
    end

    # rtm? it was not calling `rtm.start`. rtm option was removed and should be ignored
    assert_nothing_raised do
      create_driver(CONFIG + %[rtm true])
    end

    # channel should be URI.unescape-ed
    d = create_driver(CONFIG + %[space %23test])
    assert_equal 'test', d.instance.space

    # timezone should work
    d = create_driver(CONFIG + %[timezone Asia/Tokyo])
    assert_equal 'Asia/Tokyo', d.instance.timezone
  end

  def test_configure
    d = create_driver(%[
      space        space
      time_format  %Y/%m/%d %H:%M:%S
      keyfile      xxxx.json
      message      %s
      message_keys message
    ])
    assert_equal 'space', d.instance.space
    assert_equal '%Y/%m/%d %H:%M:%S', d.instance.time_format
    assert_equal 'xxxx.json', d.instance.keyfile
    assert_equal '%s', d.instance.message
    assert_equal ['message'], d.instance.message_keys

    # Allow DM
    d = create_driver(CONFIG + %[space @test])
    assert_equal '@test', d.instance.space

    assert_raise(Fluent::ConfigError) do
      create_driver(CONFIG + %[message %s %s\nmessage_keys foo])
    end

    assert_raise(Fluent::ConfigError) do
      create_driver(CONFIG + %[space %s %s\nspace_keys foo])
    end
  end

  def test_google_chat_configure
    # keyfile is missing
    assert_raise(Fluent::ConfigError) do
      create_driver(%[space foo])
    end

    # keyfile is an empty string
    assert_raise(Fluent::ConfigError) do
      create_driver(%[space foo\nkeyfile])
    end

    # space is missing
    assert_raise(Fluent::ConfigError) do
      create_driver(%[keyfile xxxx.json])
    end

    # space is an empty string
    assert_raise(Fluent::ConfigError) do
      create_driver(%[space\nkeyfile xxxx.json])
    end

    # space and keyfile filled
    assert_nothing_raised do
      create_driver(%[space space\nkeyfile xxxx.json])
    end
  end

  def test_timezone_configure
    time = Time.parse("2014-01-01 22:00:00 UTC").to_i

    d = create_driver(CONFIG + %[localtime])
    with_timezone('Asia/Tokyo') do
      assert_equal true,       d.instance.localtime
      assert_equal "07:00:00", d.instance.timef.format(time)
    end

    d = create_driver(CONFIG + %[utc])
    with_timezone('Asia/Tokyo') do
      assert_equal false,      d.instance.localtime
      assert_equal "22:00:00", d.instance.timef.format(time)
    end

    d = create_driver(CONFIG + %[timezone Asia/Taipei])
    with_timezone('Asia/Tokyo') do
      assert_equal "Asia/Taipei", d.instance.timezone
      assert_equal "06:00:00",    d.instance.timef.format(time)
    end
  end

  def test_time_format_configure
    time = Time.parse("2014-01-01 22:00:00 UTC").to_i

    d = create_driver(CONFIG + %[time_format %Y/%m/%d %H:%M:%S])
    with_timezone('Asia/Tokyo') do
      assert_equal "2014/01/02 07:00:00", d.instance.timef.format(time)
    end
  end

  def test_buffer_configure
    assert_nothing_raised do
      create_driver(CONFIG + %[buffer_type file\nbuffer_path tmp/])
    end
  end

  def test_https_proxy_configure
    # default
    d = create_driver(CONFIG)
    assert_equal nil, d.instance.slack.https_proxy
    assert_equal Net::HTTP, d.instance.slack.proxy_class

    # https_proxy
    d = create_driver(CONFIG + %[https_proxy https://proxy.foo.bar:443])
    assert_equal URI.parse('https://proxy.foo.bar:443'), d.instance.slack.https_proxy
    assert_not_equal Net::HTTP, d.instance.slack.proxy_class # Net::HTTP.Proxy
  end

  def test_default_google_chat_api
    d = create_driver(%[
      space space
      keyfile   xxxx.json
    ])
    assert_equal Fluent::SlackClient::WebApi, d.instance.slack.class
    time = Time.parse("2014-01-01 22:00:00 UTC").to_i
    d.tag  = 'test'
    mock(d.instance.google_chat).post_message(default_payload.merge({
      text:  "treasury\nspring\n",
    }), {})
    with_timezone('Asia/Tokyo') do
      d.emit({message: 'treasury'}, time)
      d.emit({message: 'spring'}, time)
      d.run
    end
  end

  def test_plain_payload
    d = create_driver(CONFIG)
    time = Time.parse("2014-01-01 22:00:00 UTC").to_i
    d.tag  = 'test'
    # attachments field should be changed to show the title
    mock(d.instance.slack).post_message(default_payload.merge({
      text: "sowawa1\nsowawa2\n",
    }), {})
    with_timezone('Asia/Tokyo') do
      d.emit({message: 'sowawa1'}, time)
      d.emit({message: 'sowawa2'}, time)
      d.run
    end
  end

  def test_message_keys
    d = create_driver(CONFIG + %[message [%s] %s %s\nmessage_keys time,tag,message])
    time = Time.parse("2014-01-01 22:00:00 UTC").to_i
    d.tag  = 'test'
    mock(d.instance.slack).post_message(default_payload.merge({
      text: "[07:00:00] test sowawa1\n[07:00:00] test sowawa2\n",
    }), {})
    with_timezone('Asia/Tokyo') do
      d.emit({message: 'sowawa1'}, time)
      d.emit({message: 'sowawa2'}, time)
      d.run
    end
  end

  def test_space_keys
    d = create_driver(CONFIG + %[space %s\nspace_keys space])
    time = Time.parse("2014-01-01 22:00:00 UTC").to_i
    d.tag  = 'test'
    mock(d.instance.slack).post_message(default_payload.merge({
      space: 'space1',
      text:    "treasury\n",
    }), {})
    mock(d.instance.slack).post_message(default_payload.merge({
      space: 'space2',
      text:    "spring\n",
    }), {})
    with_timezone('Asia/Tokyo') do
      d.emit({message: 'treasury', space: 'space1'}, time)
      d.emit({message: 'spring', space: 'space2'}, time)
      d.run
    end
  end
end
