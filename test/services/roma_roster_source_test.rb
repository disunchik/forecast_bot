require "test_helper"
require_relative "../support/roster_test_helper"

class RomaRosterSourceTest < ActiveSupport::TestCase
  include RosterTestHelper

  test "observed player cards yield 25 profiles and exclude coaching staff" do
    rows = RomaRosterSource.parse(file_fixture("roma_roster.html").read)
    assert_equal 25, rows.size
    assert_equal "Mile Svilar", rows.last.fetch("original_name")
    assert_equal RomaRosterSource.saved.fetch("players"), rows
    assert rows.none? { |row| row.fetch("key").include?("gasperini") }
  end

  test "empty incomplete malformed duplicated and oversized pages are rejected" do
    html = file_fixture("roma_roster.html").read
    [ "", "<html>Unavailable</html>", html.sub("mile-svilar", "invalid/slug"), html.sub("mile-svilar", "santiago-castro"), "x" * (RomaRosterSource::MAX_BYTES + 1) ].each do |body|
      assert_raises(RomaRosterSource::Error) { RomaRosterSource.parse(body) }
    end
  end

  test "timeouts become a recoverable source error without silently using saved data" do
    with_method_override(RomaRosterSource, :fetch, -> { raise Net::OpenTimeout }) do
      assert_raises(RomaRosterSource::Error) { RomaRosterSource.live }
    end
  end

  test "non official redirects are rejected before any connection" do
    assert_raises(RomaRosterSource::Error) { RomaRosterSource.send(:fetch, URI("https://example.com/")) }
    assert_raises(RomaRosterSource::Error) { RomaRosterSource.send(:fetch, URI("http://www.asroma.com/")) }
    assert_raises(RomaRosterSource::Error) { RomaRosterSource.send(:fetch, URI("https://www.asroma.com:8443/")) }
  end

  test "streamed body has a size cap and non success responses fail" do
    response = Net::HTTPOK.new("1.1", "200", "OK")
    response.define_singleton_method(:read_body) { |&block| block.call("x" * (RomaRosterSource::MAX_BYTES + 1)) }
    transport = Object.new
    transport.define_singleton_method(:request) { |_request, &block| block.call(response) }
    with_method_override(Net::HTTP, :start, ->(*_args, **_options, &block) { block.call(transport) }) do
      assert_raises(RomaRosterSource::Error) { RomaRosterSource.live }
    end
    response = Net::HTTPServiceUnavailable.new("1.1", "503", "Unavailable")
    with_method_override(Net::HTTP, :start, ->(*_args, **_options, &block) { block.call(transport) }) do
      assert_raises(RomaRosterSource::Error) { RomaRosterSource.live }
    end
  end
end
