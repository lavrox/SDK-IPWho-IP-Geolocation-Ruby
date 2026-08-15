$LOAD_PATH.unshift File.expand_path("lib", __dir__)
require "ipwho"

KEY = ENV["IPWHO_API_KEY"]
$pass = 0; $fail = 0
def ok(c, m); if c; $pass += 1; puts "  PASS #{m}"; else; $fail += 1; puts "  FAIL #{m}"; end; end

c = IpwhoApi::Client.new(KEY)

# 1. lookup
r = c.lookup("8.8.8.8")
d = r.data
gl = d.geoLocation; tz = d.timezone; fl = d.flag; cu = d.currency; cn = d.connection
ok(d.ip == "8.8.8.8", "lookup ip == 8.8.8.8")
ok(gl.country == "United States", "lookup country == United States (got #{gl.country})")
ok(cn.asnNumber == 15169, "lookup asnNumber == 15169 (got #{cn.asnNumber})")
ok(!gl.dialCode.nil?, "dial_code captured (#{gl.dialCode})")
ok(!gl.isInEu.nil?, "is_in_eu captured (#{gl.isInEu})")
ok(!gl.accuracyRadius.nil?, "accuracy_radius captured (#{gl.accuracyRadius})")
ok(!tz.timeZone.nil?, "time_zone captured (#{tz.timeZone})")
ok(!fl.flagIcon.nil?, "flag_Icon captured (#{fl.flagIcon})")
ok(!fl.flagUnicode.nil?, "flag_unicode captured (#{fl.flagUnicode})")
ok(!cu.namePlural.nil?, "name_plural captured (#{cu.namePlural})")
ok(!cn.asnOrg.nil?, "asn_org captured (#{cn.asnOrg})")
ok(!cn.connectionType.nil?, "connection_type captured (#{cn.connectionType})")

# 2. me
me = c.me
ok(!me.data.ip.nil?, "me ip captured (#{me.data.ip})")

# 3. bulk
b = c.bulk(["8.8.8.8", "1.1.1.1"])
arr = b.data.responseArray
ok(arr.length == 2, "bulk returns 2 (#{arr.length})")

# 4. bad key
begin
  IpwhoApi::Client.new("sk.invalid_test_key").lookup("8.8.8.8")
  ok(false, "bad key should raise")
rescue IpwhoApi::APIResponseError, IpwhoApi::InvalidIPError, IpwhoApi::RateLimitError => e
  ok(true, "bad key raised #{e.class}")
rescue => e
  ok(true, "bad key raised #{e.class}: #{e.message}")
end

puts "\nRUBY RESULT: #{$pass} passed, #{$fail} failed"
exit($fail.zero? ? 0 : 1)
