# frozen_string_literal: true

# Parent class for all Karafka consumers, contains general logic
class ApplicationConsumer < Karafka::BaseConsumer
  attr_reader :message

  def consume
    messages.each do |message|
      @message = message

      logger.info "Received message"
      consume_one

      mark_as_consumed(message)
    end
  end

  protected

  def logger
    Rails.logger
  end
end
