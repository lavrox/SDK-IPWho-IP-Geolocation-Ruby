# IPWho ([ipwho.org](https://www.ipwho.org)) Ruby SDK

[![Gem version](https://img.shields.io/gem/v/ipwho?style=flat-square)](https://rubygems.org/gems/ipwho) [![Ruby version](https://img.shields.io/badge/ruby-2.5+-red.svg)](https://www.ruby-lang.org/) [![license](https://img.shields.io/badge/license-MIT-green.svg)](https://github.com/lavrox/SDK-IPWho-IP-Geolocation-Ruby/blob/main/LICENSE)

Official Ruby SDK for the [IPWho](https://www.ipwho.org) **IP geolocation API** — geoip lookup, IP location, IP to country / latitude / longitude, ASN/ISP, timezone, currency, flag, and proxy/VPN detection. Works as an IP lookup / ip-geolocation client for IPv4 and IPv6 (`lookup`, `me`, `bulk`).

- Product: [ipwho.org](https://www.ipwho.org)
- API docs: [ipwho.org/docs](https://www.ipwho.org/docs)
- Get an API key: [ipwho.org/free-plan](https://www.ipwho.org/free-plan) (free [Lavrox](https://lavrox.com) account)
- Live API host: `https://api.ipwho.org`

## API key

Open a free [Lavrox](https://lavrox.com) account to get an API key for [IPWho](https://www.ipwho.org). Create your key at [ipwho.org/free-plan](https://www.ipwho.org/free-plan) — no credit card required.

## Installation

```bash
gem install ipwho
```

```ruby
gem "ipwho"
```

Requires Ruby >= 2.5 and Faraday. Client class: `IpwhoApi::Client`.

## Quick Start

```ruby
require "ipwho"

client = IpwhoApi::Client.new(ENV.fetch("IPWHO_API_KEY"))

res  = client.lookup("8.8.8.8")                  # GET /ip/{ip}
me   = client.me                                 # GET /me
bulk = client.bulk(["8.8.8.8", "1.1.1.1"])       # GET /bulk/{a,b,c}
```

Successful JSON:

```
IpwhoApi::IpGeoResponse
├── success
├── message
└── data  (GeoData, or OpenStruct on bulk)
    ├── ip
    ├── geoLocation
    ├── timezone
    ├── flag
    ├── currency
    ├── connection
    ├── security
    ├── userAgent
    └── responseArray   # bulk
```

## Reading the full response (8.8.8.8)

Live [IPWho](https://www.ipwho.org) values: United States, ASN 15169, America/Chicago, dial code +1.

```ruby
res  = client.lookup("8.8.8.8")
data = res.data

puts data.ip # 8.8.8.8

geo = data.geoLocation
puts geo.continent, geo.continentCode # North America, NA
puts geo.country, geo.countryCode     # United States, US
puts geo.capital, geo.region, geo.regionCode, geo.city
puts geo.postalCode, geo.dialCode     # +1
puts geo.isInEu, geo.latitude, geo.longitude, geo.accuracyRadius

tz = data.timezone
puts tz.timeZone # America/Chicago
puts tz.abbr, tz.offset, tz.isDst, tz.utc, tz.currentTime

puts data.flag.flagIcon    # 🇺🇸
puts data.flag.flagUnicode # U+1F1FA U+1F1F8

puts data.currency.code, data.currency.symbol, data.currency.name
puts data.currency.namePlural # US dollars
puts data.currency.hexUnicode

conn = data.connection
puts conn.asnNumber      # 15169
puts conn.asnOrg         # Google LLC
puts conn.isp, conn.org, conn.domain
puts conn.connectionType # Corporate

puts data.security.isVpn, data.security.isTor, data.security.isThreat

if data.userAgent
  puts data.userAgent.browser.name, data.userAgent.os.name
end

me = client.me
puts me.data.ip

bulk = client.bulk(["8.8.8.8", "1.1.1.1"])
Array(bulk.data.responseArray).each do |item|
  puts item.data.ip, item.data.geoLocation.country
end
```

### Example JSON (mapped fields)

```json
{
  "success": true,
  "data": {
    "ip": "8.8.8.8",
    "geoLocation": {
      "country": "United States",
      "countryCode": "US",
      "dialCode": "+1",
      "isInEu": false
    },
    "timezone": { "timeZone": "America/Chicago" },
    "flag": { "flagIcon": "🇺🇸", "flagUnicode": "U+1F1FA U+1F1F8" },
    "currency": { "code": "USD", "namePlural": "US dollars" },
    "connection": {
      "asnNumber": 15169,
      "asnOrg": "Google LLC",
      "connectionType": "Corporate"
    },
    "security": { "isVpn": false, "isTor": false, "isThreat": "low" }
  }
}
```

## API Reference

### `IpwhoApi::Client.new(api_key, options = {})`

Required key (query `apiKey`). `options[:base_url]` default `https://api.ipwho.org`. `options[:timeout]` default `30`.

### `lookup(ip, options = {})`

`options[:format]` json|xml|csv. `options[:fields]` comma-separated filter.

### `me(options = {})`

### `bulk(ips)`

Per-IP rows on `data.responseArray`.

### Errors

`IpwhoApi::InvalidIPError` (404), `RateLimitError` (429), `APIResponseError`.

## Type Definitions

Structs (keyword init):

- **GeoLocation**: `continent`, `continentCode`, `country`, `countryCode`, `capital`, `region`, `regionCode`, `city`, `postalCode`, `dialCode`, `isInEu`, `latitude`, `longitude`, `accuracyRadius`
- **Timezone**: `timeZone`, `abbr`, `offset`, `isDst`, `utc`, `currentTime`
- **Flag**: `flagIcon`, `flagUnicode`
- **Currency**: `code`, `symbol`, `name`, `namePlural`, `hexUnicode`
- **Connection**: `asnNumber`, `asnOrg`, `isp`, `org`, `domain`, `connectionType`
- **Security**: `isVpn`, `isTor`, `isThreat`
- **UserAgent**: `browser`, `engine`, `os`, `device`, `cpu`
- **GeoData**: `ip` plus the objects above
- **IpGeoResponse**: `success`, `data`, `message`

Wire keys such as `postal_Code` and `flag_Icon` are mapped onto these members.

## Troubleshooting

- Empty key → `APIResponseError`. Key: [ipwho.org](https://www.ipwho.org).
- HTTP 403: SDK sends `ipwho-ruby-sdk/1.0.0`.
- HTTP 429 / 404: `RateLimitError` / `InvalidIPError`.
- Nil nested structs on some IPs.

## Testing

```bash
IPWHO_API_KEY=your_key ruby test_ipwho.rb
```

The live check is `test_ipwho.rb`.

## Changelog

### v1.0.0

- `lookup`, `me`, `bulk` matching [api.ipwho.org](https://api.ipwho.org)
- Full typed Struct models

## License

MIT License — see [LICENSE](LICENSE).

## Support

- Documentation: [ipwho.org/docs](https://www.ipwho.org/docs)
- Contact: [ipwho.org/contact](https://www.ipwho.org/contact)
- GitHub Issues: [lavrox/SDK-IPWho-IP-Geolocation-Ruby](https://github.com/lavrox/SDK-IPWho-IP-Geolocation-Ruby/issues)
- Website: [ipwho.org](https://www.ipwho.org)

---

[IPWho](https://www.ipwho.org) — a [Lavrox](https://lavrox.com) network API.

[Lavrox](https://lavrox.com) — Independent API infrastructure. Lower latency, lower cost.
