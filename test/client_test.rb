# frozen_string_literal: true

# Runs against a local stand-in server that replays recorded API responses.
# No API key and no network access are needed.

require "minitest/autorun"
require "socket"
require "ipwho"

class ClientTest < Minitest::Test
  KEY = "sk.test_secret_value"

  def setup
    @requests = []
    reply(200, fixture("lookup"))
    @server = TCPServer.new("127.0.0.1", 0)
    @thread = Thread.new { serve }
    @client = IpwhoApi::Client.new(KEY, base_url: "http://127.0.0.1:#{@server.addr[1]}", timeout: 5)
  end

  def teardown
    @thread.kill
    @thread.join
    @server.close
  end

  def test_key_is_in_the_header_and_never_in_the_url
    @client.lookup("8.8.8.8")
    @client.me
    reply(200, fixture("bulk"))
    @client.bulk(["8.8.8.8", "1.1.1.1"])

    assert_equal 3, @requests.length
    @requests.each do |request|
      assert_equal "Bearer #{KEY}", request[:headers]["authorization"]
      assert_equal "ipwho-ruby-sdk/#{IpwhoApi::VERSION}", request[:headers]["user-agent"]
      refute_includes request[:target], KEY
      refute_match(/api_?key/i, request[:target])
    end
  end

  def test_lookup_maps_the_response
    data = @client.lookup("8.8.8.8").data
    assert_equal "/ip/8.8.8.8", @requests[0][:target]
    assert_equal "8.8.8.8", data.ip
    assert_equal "United States", data.geoLocation.country
    assert_equal "US", data.geoLocation.countryCode
    assert_equal "+1", data.geoLocation.dialCode
    assert_equal 15169, data.connection.asnNumber
    assert_equal "America/Chicago", data.timezone.timeZone
    assert_equal "USD", data.currency.code
    assert_equal Encoding::UTF_8, data.flag.flagIcon.encoding
  end

  def test_lookup_accepts_a_null_currency
    reply(200, fixture("lookup-null-currency"))
    data = @client.lookup("1.1.1.1").data
    assert_equal "1.1.1.1", data.ip
    assert_nil data.currency
  end

  def test_bulk_returns_the_data_for_every_address
    reply(200, fixture("bulk"))
    rows = @client.bulk(["8.8.8.8", "1.1.1.1", "192.168.0.1", "9.9.9.9"]).data.responseArray
    assert_equal 4, rows.length

    assert rows[0].success
    assert_equal "8.8.8.8", rows[0].data.ip
    assert_equal "United States", rows[0].data.geoLocation.country
    assert_equal 15169, rows[0].data.connection.asnNumber

    assert rows[1].success
    assert_equal "1.1.1.1", rows[1].data.ip
    assert_nil rows[1].data.currency

    refute rows[2].success
    assert_equal "192.168.0.1", rows[2].data.ip
    assert_nil rows[2].data.geoLocation
    assert_equal "Reserved range/Invalid IP address", rows[2].message

    refute rows[3].success
    assert_equal "9.9.9.9", rows[3].data.ip
    assert_match(/quota/, rows[3].message)
  end

  def test_fields_and_format_are_the_only_query_parameters
    @client.lookup("8.8.8.8", fields: "geoLocation,timezone")
    assert_equal "/ip/8.8.8.8?get=geoLocation%2Ctimezone", @requests[0][:target]
    reply(200, "ip,8.8.8.8")
    assert_equal "ip,8.8.8.8", @client.lookup("8.8.8.8", format: "csv").data.ip
    assert_equal "/ip/8.8.8.8?format=csv", @requests[1][:target]
  end

  {
    404 => ['{"success":false,"message":"Reserved range/Invalid IP address"}', IpwhoApi::InvalidIPError],
    429 => ['{"error":"rate_limit_exceeded"}', IpwhoApi::RateLimitError],
    401 => ['{"error":"invalid_api_key"}', IpwhoApi::APIResponseError]
  }.each do |status, (body, expected)|
    define_method("test_http_#{status}_raises") do
      reply(status, body)
      error = assert_raises(expected) { @client.lookup("8.8.8.8") }
      refute_includes error.message, KEY
    end
  end

  def test_a_timeout_is_not_retried
    @delay = 2
    client = IpwhoApi::Client.new(KEY, base_url: "http://127.0.0.1:#{@server.addr[1]}", timeout: 0.5)
    assert_raises(IpwhoApi::APIResponseError) { client.lookup("8.8.8.8") }
    sleep 3
    assert_equal 1, @requests.length
  end

  def test_connection_failure_raises_without_the_key
    unreachable = IpwhoApi::Client.new(KEY, base_url: "http://127.0.0.1:1", timeout: 5)
    error = assert_raises(IpwhoApi::APIResponseError) { unreachable.lookup("8.8.8.8") }
    assert_match(/\ARequest failed:/, error.message)
    refute_includes error.message, KEY
  end

  def test_faraday_is_not_loaded
    refute defined?(Faraday)
  end

  private

  def fixture(name)
    File.read(File.join(__dir__, "fixtures", "#{name}.json"), encoding: "UTF-8")
  end

  def reply(status, body)
    @status = status
    @body = body
  end

  # A very small HTTP server: one thread per connection.
  def serve
    loop do
      socket = @server.accept
      Thread.new(socket) { |connection| answer(connection) }
    end
  end

  def answer(socket)
    target = socket.gets.to_s.split(" ")[1]
    headers = {}
    while (line = socket.gets) && line != "\r\n"
      name, value = line.split(":", 2)
      headers[name.downcase] = value.strip
    end
    @requests << { target: target, headers: headers }
    sleep @delay if @delay
    socket.write("HTTP/1.1 #{@status} Test\r\nContent-Type: application/json\r\n" \
                 "Content-Length: #{@body.bytesize}\r\nConnection: close\r\n\r\n")
    socket.write(@body)
  rescue IOError, SystemCallError
    # The client went away, which the timeout test does on purpose.
  ensure
    socket.close
  end
end
