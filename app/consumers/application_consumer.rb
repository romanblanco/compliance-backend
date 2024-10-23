# frozen_string_literal: true

# Application consumer from which all Karafka consumers should inherit
# You can rename it if it would conflict with your current code base (in case you're integrating
# Karafka with other frameworks)
class ApplicationConsumer < Karafka::BaseConsumer
  attr_reader :msg_value
  def consume
    messages.each do |message|
      @msg_value = message
      consume_one

      mark_as_consumed(message)
    end
  end

  def consume_one
    logger.info "Received message, enqueueing: #{@msg_value}"
  end

  def logger
    Rails.logger
  end
end
