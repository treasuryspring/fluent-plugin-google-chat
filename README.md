# fluent-plugin-google-chat [![Build Status](https://travis-ci.org/treasuryspring/fluent-plugin-google-chat.svg)](https://travis-ci.org/treasuryspring/fluent-plugin-google-chat)

This plugin is largely inspired by [fluent-plugin-slack](https://github.com/sowawa/fluent-plugin-slack).

# Installation

```
$ fluent-gem install fluent-plugin-google-chat
```

# Usage (Web API a.k.a. Bots)

```apache
<match google_chat>
  @type google_chat
  keyfile /tmp/mykeyfile.json
  space AAABBBcdefG
  flush_interval 60s
</match>
```

```ruby
fluent_logger.post('google_chat', {
  :message  => 'Hello<br>World!'
})
```

### Parameter

|parameter|description|default|
|---|---|---|
|keyfile|Private key file generated on Google Cloud Platform. See https://developers.google.com/hangouts/chat/how-tos/bots-publish#enabling_the_hangouts_chat_api||
|space|Room name to send messages. Can be found in the URL of the chat room.||
|space_keys|keys used to format space. %s will be replaced with value specified by space_keys if this option is used|nil|
|message|message format. %s will be replaced with value specified by message_keys|%s|
|message_keys|keys used to format messages|message|
|https_proxy|https proxy url such as `https://proxy.foo.bar:443`|nil|
|verbose_fallback|If this option is set to be `true`, messages are included to the fallback attribute|false|

`fluent-plugin-google-chat` uses `SetTimeKeyMixin` and `SetTagKeyMixin`, so you can also use:

|parameter|description|default|
|---|---|---|
|timezone|timezone such as `Asia/Tokyo`||
|localtime|use localtime as timezone|true|
|utc|use utc as timezone||
|time_key|key name for time used in xxx_keys|time|
|time_format|time format. This will be formatted with Time#strftime.|%H:%M:%S|
|tag_key|key name for tag used in xxx_keys|tag|

`fluent-plugin-google-chat` is a kind of BufferedOutput plugin, so you can also use [Buffer Parameters](http://docs.fluentd.org/articles/out_exec#buffer-parameters).

## ChangeLog

See [CHANGELOG.md](CHANGELOG.md) for details.

# Copyright

* Copyright:: Copyright (c) 2020 - TreasurySpring
* License::   Apache License, Version 2.0

