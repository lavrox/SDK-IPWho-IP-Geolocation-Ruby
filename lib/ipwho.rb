# frozen_string_literal: true

# IPWho Ruby SDK v1.0.0
# ======================
#
# Enterprise-grade client for the IPWho IP Geolocation API.
# Requires Ruby >= 2.5, faraday ~> 1.0, json.
#
# Endpoints:
#   - lookup(ip)     — geolocation for a specific IPv4/IPv6 address
#   - me()           — geolocation for the caller's IP
#   - bulk(ips)      — batch lookup for multiple IPs
#
# API docs: https://api.ipwho.org

require "json"
require "faraday"
require "ostruct"
require "erb"

module IpwhoApi
  VERSION = "1.0.0".freeze

  # ── Exceptions ────────────────────────────────────────────────────

  class Error < StandardError; end
  class InvalidIPError < Error; end
  class RateLimitError < Error; end
  class APIResponseError < Error; end

  # ── Data objects (Struct-based, mirror OpenAPI schema) ────────────

  # All data objects use camelCase keys matching the API response.

  GeoLocation = Struct.new(
    :continent, :continentCode, :country, :countryCode, :capital,
    :region, :regionCode, :city, :postalCode, :dialCode,
    :isInEu, :latitude, :longitude, :accuracyRadius,
    keyword_init: true
  ) do
    def self.from_hash(hash)
      new(
        continent:      hash["continent"],
        continentCode:  hash["continentCode"],
        country:        hash["country"],
        countryCode:    hash["countryCode"],
        capital:        hash["capital"],
        region:         hash["region"],
        regionCode:     hash["regionCode"],
        city:           hash["city"],
        postalCode:     hash["postal_Code"],
        dialCode:       hash["dial_code"],
        isInEu:         hash["is_in_eu"],
        latitude:       hash["latitude"],
        longitude:      hash["longitude"],
        accuracyRadius: hash["accuracy_radius"]
      )
    end
  end

  Timezone = Struct.new(
    :timeZone, :abbr, :offset, :isDst, :utc, :currentTime,
    keyword_init: true
  ) do
    def self.from_hash(hash)
      new(
        timeZone:    hash["time_zone"],
        abbr:        hash["abbr"],
        offset:      hash["offset"],
        isDst:       hash["is_dst"],
        utc:         hash["utc"],
        currentTime: hash["current_time"]
      )
    end
  end

  Flag = Struct.new(:flagIcon, :flagUnicode, keyword_init: true) do
    def self.from_hash(hash)
      new(flagIcon: hash["flag_Icon"], flagUnicode: hash["flag_unicode"])
    end
  end

  Currency = Struct.new(
    :code, :symbol, :name, :namePlural, :hexUnicode,
    keyword_init: true
  ) do
    def self.from_hash(hash)
      new(
        code:       hash["code"],
        symbol:     hash["symbol"],
        name:       hash["name"],
        namePlural: hash["name_plural"],
        hexUnicode: hash["hex_unicode"]
      )
    end
  end

  Connection = Struct.new(
    :asnNumber, :asnOrg, :isp, :org, :domain, :connectionType,
    keyword_init: true
  ) do
    def self.from_hash(hash)
      new(
        asnNumber:      hash["asn_number"],
        asnOrg:         hash["asn_org"],
        isp:            hash["isp"],
        org:            hash["org"],
        domain:         hash["domain"],
        connectionType: hash["connection_type"]
      )
    end
  end

  Security = Struct.new(:isVpn, :isTor, :isThreat, keyword_init: true) do
    def self.from_hash(hash)
      new(
        isVpn:    hash["isVpn"],
        isTor:    hash["isTor"],
        isThreat: hash["isThreat"]
      )
    end
  end

  UserAgentBrowser = Struct.new(:name, :version, keyword_init: true) do
    def self.from_hash(hash)
      new(name: hash["name"], version: hash["version"])
    end
  end

  UserAgentEngine = Struct.new(:name, :version, keyword_init: true) do
    def self.from_hash(hash)
      new(name: hash["name"], version: hash["version"])
    end
  end

  UserAgentOS = Struct.new(:name, :version, keyword_init: true) do
    def self.from_hash(hash)
      new(name: hash["name"], version: hash["version"])
    end
  end

  UserAgentDevice = Struct.new(:type, :vendor, :model, keyword_init: true) do
    def self.from_hash(hash)
      new(type: hash["type"], vendor: hash["vendor"], model: hash["model"])
    end
  end

  UserAgentCPU = Struct.new(:architecture, keyword_init: true) do
    def self.from_hash(hash)
      new(architecture: hash["architecture"])
    end
  end

  UserAgent = Struct.new(:browser, :engine, :os, :device, :cpu, keyword_init: true) do
    def self.from_hash(hash)
      new(
        browser: hash["browser"] ? UserAgentBrowser.from_hash(hash["browser"]) : nil,
        engine:  hash["engine"]  ? UserAgentEngine.from_hash(hash["engine"])   : nil,
        os:      hash["os"]      ? UserAgentOS.from_hash(hash["os"])           : nil,
        device:  hash["device"]  ? UserAgentDevice.from_hash(hash["device"])   : nil,
        cpu:     hash["cpu"]     ? UserAgentCPU.from_hash(hash["cpu"])         : nil
      )
    end
  end

  GeoData = Struct.new(
    :ip, :geoLocation, :timezone, :flag, :currency, :connection, :security, :userAgent,
    keyword_init: true
  ) do
    def self.from_hash(hash)
      new(
        ip:          hash["ip"] || "",
        geoLocation: hash["geoLocation"] ? GeoLocation.from_hash(hash["geoLocation"]) : nil,
        timezone:    hash["timezone"]    ? Timezone.from_hash(hash["timezone"])       : nil,
        flag:        hash["flag"]        ? Flag.from_hash(hash["flag"])               : nil,
        currency:    hash["currency"]    ? Currency.from_hash(hash["currency"])       : nil,
        connection:  hash["connection"]  ? Connection.from_hash(hash["connection"])   : nil,
        security:    hash["security"]    ? Security.from_hash(hash["security"])       : nil,
        userAgent:   hash["userAgent"]   ? UserAgent.from_hash(hash["userAgent"])     : nil
      )
    end
  end

  ErrorResponse = Struct.new(:success, :message, keyword_init: true) do
    def self.from_hash(hash)
      new(success: hash["success"], message: hash["message"])
    end
  end

  IpGeoResponse = Struct.new(:success, :data, :message, keyword_init: true) do
    def self.from_hash(hash)
      data_obj = nil
      if hash["data"].is_a?(Hash)
        # Bulk: normalise responseArray
        if hash["data"]["responseArray"].is_a?(Array)
          data_obj = hash["data"].dup
          data_obj["responseArray"] = hash["data"]["responseArray"].map { |item| IpGeoResponse.from_hash(item) }
          data_obj = OpenStruct.new(data_obj)
        else
          data_obj = GeoData.from_hash(hash["data"])
        end
      end
      new(success: hash["success"], data: data_obj, message: hash["message"])
    end
  end

  # ── Client ──────────────────────────────────────────────────────────

  class Client
    DEFAULT_BASE_URL = "https://api.ipwho.org".freeze

    # @param api_key [String] Your IPWho API key (required).
    # @param options [Hash]
    # @option options [String] :base_url Override base URL (default https://api.ipwho.org).
    # @option options [Numeric] :timeout Request timeout in seconds (default 30).
    def initialize(api_key, options = {})
      raise APIResponseError, "api_key is required" if api_key.nil? || api_key.empty?

      @api_key = api_key
      @base_url = (options[:base_url] || DEFAULT_BASE_URL).sub(%r{/+$}, "")
      @timeout = options[:timeout] || 30
    end

    # ── public API ──────────────────────────────────────────────────

    # Look up geolocation for a specific IPv4 or IPv6 address.
    #
    # @param ip [String] The IP address.
    # @param options [Hash]
    # @option options [String] :format json|xml|csv (default json)
    # @option options [String] :fields Comma-separated fields filter
    # @return [IpwhoApi::IpGeoResponse]
    # @raise [IpwhoApi::InvalidIPError] – 404
    # @raise [IpwhoApi::RateLimitError] – 429
    # @raise [IpwhoApi::APIResponseError] – other errors
    def lookup(ip, options = {})
      format = options[:format] || "json"
      params = build_params(format, options[:fields])
      get("/ip/#{ERB::Util.url_encode(ip)}", params, format)
    end

    # Look up geolocation for the caller's own IP address.
    #
    # @param options [Hash]
    # @option options [String] :format json|xml|csv (default json)
    # @option options [String] :fields Comma-separated fields filter
    # @return [IpwhoApi::IpGeoResponse]
    # @raise [IpwhoApi::APIResponseError]
    def me(options = {})
      format = options[:format] || "json"
      params = build_params(format, options[:fields])
      get("/me", params, format)
    end

    # Batch-lookup multiple IP addresses.
    #
    # @param ips [Array<String>] List of IPv4 or IPv6 addresses.
    # @return [IpwhoApi::IpGeoResponse] Response with data.responseArray of IpGeoResponse.
    # @raise [IpwhoApi::APIResponseError]
    def bulk(ips)
      raise APIResponseError, "ips must not be empty" if ips.nil? || ips.empty?

      bulk_param = ips.join(",")
      params = { apiKey: @api_key }
      get("/bulk/#{ERB::Util.url_encode(bulk_param)}", params, "json")
    end

    private

    # Build query parameters.
    def build_params(format, fields)
      params = { apiKey: @api_key }
      params[:format] = format if format != "json"
      params[:get]    = fields if fields && !fields.empty?
      params
    end

    # Execute a GET request and return typed response.
    def get(path, params, format)
      conn = Faraday.new(url: @base_url) do |f|
        f.headers["Accept"]     = "application/json"
        f.headers["User-Agent"] = "ipwho-ruby-sdk/#{VERSION}"
        f.options.timeout       = @timeout
        f.options.open_timeout  = @timeout
        f.adapter Faraday.default_adapter
      end

      response = conn.get(path, params)
      status   = response.status
      body     = response.body

      # Rate limit
      raise RateLimitError, error_message(body, status) if status == 429

      # Not found
      raise InvalidIPError, error_message(body, status) if status == 404

      # Other HTTP errors
      raise APIResponseError, "HTTP #{status}: #{error_message(body, status)}" unless status >= 200 && status < 300

      # Non-JSON formats: wrap raw text
      unless format == "json"
        return IpGeoResponse.new(
          success: true,
          data: GeoData.new(ip: body),
          message: nil
        )
      end

      # JSON success path
      payload = JSON.parse(body)

      # Logical error in success=false
      if payload["success"] == false
        raise APIResponseError, payload["message"] || "API returned success=false"
      end

      IpGeoResponse.from_hash(payload)
    rescue Faraday::Error => e
      raise APIResponseError, "Request failed: #{e.message}"
    rescue JSON::ParserError
      raise APIResponseError, "Invalid JSON response"
    end

    # Best-effort extraction of error message.
    def error_message(body, _status)
      return "Unknown API error" if body.nil? || body.empty?

      parsed = JSON.parse(body) rescue nil
      return parsed["message"] if parsed.is_a?(Hash) && parsed["message"]

      body
    end
  end
end

# ═══════════════════════════════════════════════════════════════════════
# Example usage
# ═══════════════════════════════════════════════════════════════════════

if __FILE__ == $PROGRAM_NAME
  require "json"
  require "faraday"
  require "ostruct"
  require "erb"

  api_key = ENV["IPWHO_API_KEY"] || "sk.xxxx"
  client = IpwhoApi::Client.new(api_key)

  # Single lookup
  resp = client.lookup("8.8.8.8")
  if resp.data&.geoLocation
    gl = resp.data.geoLocation
    puts "IP: #{resp.data.ip}  |  #{gl.city}, #{gl.country} (#{gl.latitude}, #{gl.longitude})"
  end
  if resp.data&.currency
    puts "Currency: #{resp.data.currency.code} (#{resp.data.currency.symbol})"
  end

  # Self lookup
  me = client.me
  puts "\nMy IP: #{me.data&.ip || 'unknown'}"

  # Bulk
  bulk = client.bulk(["8.8.8.8", "1.1.1.1"])
  puts "\nBulk: success=#{bulk.success}"
end