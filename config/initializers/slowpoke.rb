Rails.application.configure do
  config.slowpoke.timeout = 25
end
ActiveSupport::Notifications.subscribe "timeout.slowpoke" do |_name, _start, _finish, _id, payload|
  request = Rack::Request.new(payload[:env])
  error = payload[:error] || Appsignal::SimpleMessage.new("Request timed out")

  Appsignal.report_error(error) do |transaction|
    transaction.set_action(request.request_method)
    # Keep timeout diagnostics useful without exporting request content or
    # identity/network identifiers to the error tracker.
    transaction.set_tags(path: request.path)
  end
end
