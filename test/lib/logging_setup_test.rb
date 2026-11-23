require "test_helper"

class LoggingSetupTest < ActiveSupport::TestCase
  test "production logger always writes to stdout" do
    io = StringIO.new
    logger = LoggingSetup.production_logger(stdout: io, appsignal: false)

    logger.info("admin.user.promote")

    assert_includes io.string, "admin.user.promote"
  end

  test "appsignal is only in the broadcast when configured" do
    logger = LoggingSetup.production_logger(stdout: StringIO.new, appsignal: false)

    assert_equal 1, logger.broadcasts.size
    assert_not logger.broadcasts.any? { |sink| sink.is_a?(Appsignal::Logger) }

    logger = LoggingSetup.production_logger(stdout: StringIO.new, appsignal: true)

    assert_equal 2, logger.broadcasts.size
    assert logger.broadcasts.any? { |sink| sink.is_a?(Appsignal::Logger) }
  end

  test "keeps the existing formatter" do
    io = StringIO.new
    formatter = ->(severity, _time, _program, message) { "#{severity}: #{message}\n" }
    logger = LoggingSetup.production_logger(stdout: io, appsignal: false, formatter:)

    logger.info("hello")

    assert_equal "INFO: hello\n", io.string
  end

  test "tags still reach the stdout sink" do
    io = StringIO.new
    logger = LoggingSetup.production_logger(stdout: io, appsignal: false)

    logger.tagged("request-1") { logger.info("tagged") }

    assert_includes io.string, "[request-1]"
    assert_includes io.string, "tagged"
  end
end
