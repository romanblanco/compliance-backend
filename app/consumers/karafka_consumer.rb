# Parent class for all Karafka consumers, contains general logic

# TODO: this should eventually become ApplicationConsumer
class KarafkaConsumer < Karafka::BaseConsumer
  attr_reader :message

  def consume(messages)
    messages.each do |message|
      @message = JSON.parse(message.raw_payload)

      consume_one
      logger.info "Received message, enqueueing: #{@message}"
      # FIXME:
      # Received message, enqueueing: {"ping"=>"pong"}
      # Consumer consuming error: undefined method `offset' for an instance of Hash
      puts "\n\u001b[31;1m◉\u001b[0m app/consumers/karafka_consumer.rb"
      puts "message: #{message}"
      puts "message.class: #{message.class}"
      puts "message.raw_payload: #{message.raw_payload}"
      puts "-" * 40

      mark_as_consumed message
    end
  end

  protected

  def logger
    Rails.logger
  end
end
