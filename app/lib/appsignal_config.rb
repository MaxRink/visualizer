module AppsignalConfig
  module_function

  # AppSignal is only a real sink when it has a key; without one its logger
  # drops every line, so the production logger must not depend on it.
  def configured?
    ENV["APPSIGNAL_PUSH_API_KEY"].present? || Rails.application.credentials.appsignal.present?
  end
end
