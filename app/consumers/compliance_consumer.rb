# frozen_string_literal: true

class ComplianceConsumer < KarafkaConsumer
  def consume
    super(messages)
  end

  def consume_one
    puts "\n\u001b[31;1m◉\u001b[0m app/consumers/compliance_consumer.rb"
    puts "message: #{message}"
    puts "-" * 40
  end
end
