# frozen_string_literal: true

# Parent class for all Karafka consumers, contains general logic
# TODO: this should eventually become ApplicationConsumer
class KarafkaConsumer < Karafka::BaseConsumer
  attr_reader :message

  def consume
    messages.each do |message|
      @message = message

      logger.info "Received message, processing: #{@message.payload}"

      consume_one

      # FIXME: Consumer consuming error: wrong number of arguments (given 2, expected 1)
      puts "\n\u001b[31;1m◉\u001b[0m app/consumers/karafka_consumer.rb#consume"
      puts "@message.class: #{@message}"
      puts "message.class: #{message.class}"
      puts "message: #{message}"
      puts "message.payload: #{message.payload}"
      puts "message.offset: #{message.offset}"
      puts "topic.to_h: #{topic.to_h}"
      puts "-" * 40
      # binding.pry

      mark_as_consumed(message)
    end
  end

  protected

  def logger
    Rails.logger
  end
end
