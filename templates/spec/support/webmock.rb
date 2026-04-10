require "webmock/rspec"

# Allow localhost connections for system tests and test server
WebMock.disable_net_connect!(allow_localhost: true)
