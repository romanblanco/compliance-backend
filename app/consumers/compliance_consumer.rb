# frozen_string_literal: true

# Receives messages from the Kafka topic, dispatches them to the appropriate service
class ComplianceConsumer < ApplicationConsumer
  # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
  def consume_one
    # rubocop:disable Rails/Output
    puts "\n\u001b[31;1m◉\u001b[0m app/services/kafka/policy_system_importer.rb"
    puts "payload: #{payload}"
    puts "Settings.kafka.topics: #{Settings.kafka.topics}"
    puts '-' * 40
    # rubocop:enable Rails/Output
    if service == 'compliance'
      Kafka::ReportParser.new(payload, logger).parse_reports
    elsif message_type == 'created' && image_builder?
      Kafka::PolicySystemImporter.new(payload, logger).import
    elsif message_type == 'delete'
      Kafka::HostRemover.new(payload, logger).remove_host
    else
      logger.debug "Skipped message of type #{message_type}"
    end
  end
  # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

  private

  def payload
    JSON.parse(@message.raw_payload)
  end

  def service
    payload.dig('platform_metadata', 'service')
  end

  def message_type
    payload.dig('type')
  end

  def image_builder?
    payload.dig('host', 'image_builder', 'compliance_policy_id').present?
  end
end
