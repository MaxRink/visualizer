require "test_helper"
require "json"
require "socket"
require "timeout"

class PrometheusExporterClientTest < ActiveSupport::TestCase
  test "pinned exporter client accepts histogram registration and sends observation" do
    server = TCPServer.new("127.0.0.1", 0)
    payload = Queue.new
    reader = Thread.new do
      socket = server.accept
      socket.gets until (line = socket.gets) == "\r\n" || line.nil?
      body = +""
      loop do
        size_line = socket.gets
        break if size_line.nil?

        size = size_line.to_i(16)
        break if size.zero?

        body << socket.read(size)
        socket.read(2)
      end
      payload << JSON.parse(body)
    ensure
      socket&.close
    end

    client = PrometheusExporter::Client.new(host: "127.0.0.1", port: server.addr[1])
    metric = client.register(
      :histogram,
      "visualizer_http_request_duration_seconds",
      "HTTP request duration in seconds."
    )
    metric.observe(0.125, method: "GET", route: "rails/health#show", status: "200")
    client.stop(wait_timeout_seconds: 2)

    observation = Timeout.timeout(2) { payload.pop }
    assert_equal "histogram", observation.fetch("type")
    assert_equal "visualizer_http_request_duration_seconds", observation.fetch("name")
    assert_equal 0.125, observation.fetch("value")
    assert_equal({"method" => "GET", "route" => "rails/health#show", "status" => "200"}, observation.fetch("keys"))
  ensure
    reader&.join(2)
    server&.close
  end
end
