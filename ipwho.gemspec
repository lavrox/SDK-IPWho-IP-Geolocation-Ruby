# frozen_string_literal: true

require_relative "lib/ipwho"

Gem::Specification.new do |spec|
  spec.name          = "ipwho"
  spec.version       = IpwhoApi::VERSION
  spec.authors       = ["IPWho SDK Contributors"]
  spec.email         = ["info@ipwho.org"]

  spec.summary       = "Official Ruby SDK for the IPWho IP geolocation API (lookup, me, bulk)."
  spec.description   = "Geoip lookup, IP location, ASN/ISP, timezone, currency, flag, and VPN/proxy detection for IPv4 and IPv6 via api.ipwho.org."
  spec.homepage      = "https://www.ipwho.org"
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 2.5.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/lavrox/SDK-IPWho-IP-Geolocation-Ruby"
  spec.metadata["changelog_uri"] = "https://github.com/lavrox/SDK-IPWho-IP-Geolocation-Ruby/blob/main/CHANGELOG.md"
  spec.metadata["bug_tracker_uri"] = "https://github.com/lavrox/SDK-IPWho-IP-Geolocation-Ruby/issues"
  spec.metadata["documentation_uri"] = "https://www.ipwho.org/docs"
  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir["lib/**/*.rb", "LICENSE", "README.md", "CHANGELOG.md"]
  spec.require_paths = ["lib"]

  spec.add_dependency "faraday", "~> 1.0"
end
