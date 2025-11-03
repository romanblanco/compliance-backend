# frozen_string_literal: true

require 'unleash'

if ENV['UNLEASH_URL'].nil?
  UNLEASH = nil
  Rails.logger.info 'Unleash URL not configured, feature flags disabled'
  return
end

Unleash.configure do |config|
  config.app_name = Rails.application.class.module_parent_name
  config.url = ENV['UNLEASH_URL']
  config.bootstrap_config = Unleash::Bootstrap::Configuration.new(
    data: {
      'kessel_enabled' => {
        'enabled' => false,
        'strategies' => []
      }
    }
  )
  config.custom_http_headers = ENV['UNLEASH_TOKEN'].present? ? { 'Authorization' => ENV['UNLEASH_TOKEN'] } : nil
end

begin
  UNLEASH = Unleash::Client.new
  Rails.logger.info "Unleash client initialized: URL=#{ENV['UNLEASH_URL']}, App=#{unleash_config[:app_name]}"

rescue StandardError => e
  Rails.logger.error "Failed to initialize Unleash client: #{e.message}"
  # Set to nil so we can check if Unleash is available
  UNLEASH = nil
end