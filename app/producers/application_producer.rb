# frozen_string_literal: true

require 'karafka'

# Common Kafka producer client
class ApplicationProducer
  BROKERS = Settings.kafka.brokers.split(',').freeze
  EXCEPTIONS = [Rdkafka::RdkafkaError, Rdkafka::AbstractHandle::WaitTimeoutError].freeze
  SERVICE = 'compliance'
  DATE_FORMAT = :iso8601
  # Define TOPIC in the inherited class.
  # Example:
  #   TOPIC = 'platform.payload-status'

  class << self
    def ping
      # The partition count method fails if the connection is not alive, so we are
      # sending a random topic name to it for status checks.
      kafka.partition_count(Settings.kafka.topics.to_h.values.compact.sample)
    end

    private

    def deliver_message(msg)
      msg = msg.merge(
        date: DateTime.now.utc.send(self::DATE_FORMAT),
        service: SERVICE,
        source: ENV.fetch('APPLICATION_TYPE', nil)
      )
      kafka&.produce_sync(payload: msg.to_json, topic: self::TOPIC)
    end

    def logger
      Rails.logger
    end

    def kafka
      @kafka ||= WaterDrop::Producer.new if self::BROKERS.any?
    end
  end
end
