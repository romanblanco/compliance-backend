# frozen_string_literal: true

# Receives messages from the Kafka topic, converts them into jobs for processing
class ComplianceConsumer < ApplicationConsumer
  include ParseReport

  def consume_one
    if service == 'compliance'
      parse_reports
    end
  end

  private

  def metadata
    message.payload.dig('platform_metadata') || {}
  end

  def service
    metadata.dig('service')
  end

  def account
    metadata.dig('account')
  end

  def org_id
    metadata.dig('org_id')
  end

  def request_id
    metadata.dig('request_id')
  end

  def b64_identity
    metadata.dig('b64_identity')
  end

  def identity
    Insights::Api::Common::IdentityHeader.new(b64_identity)
  end
end
