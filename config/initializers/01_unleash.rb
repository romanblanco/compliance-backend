# frozen_string_literal: true

require 'unleash'

Unleash.configure do |config|
  config.app_name = Rails.application.class.module_parent_name
  config.url = ENV['UNLEASH_URL']
  config.custom_http_headers = proc {
    { 'Authorization' => ENV['UNLEASH_TOKEN'] }
  end
  config.instance_id = "#{Socket.gethostname}"
  config.bootstrap_config = Unleash::Bootstrap::Configuration.new(
    data: {
      'compliance.kessel_enabled' => {
        'enabled' => false,
        'strategies' => []
      }
    }.to_json
  )
end

Rails.configuration.unleash = Unleash::Client.new
Rails.logger.info "Unleash client initialized: URL=#{ENV['UNLEASH_URL']}, App=#{Rails.application.class.module_parent_name}"
