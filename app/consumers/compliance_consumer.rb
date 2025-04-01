# frozen_string_literal: true

class ComplianceConsumer < KarafkaConsumer
  def consume_one
    if message.payload['type'] == 'created'
      system = message.payload.dig('host', 'id')
      policy = message.payload.dig('host', 'facts', 'image_builder', 'compliance_policy_id')
    else
      policy, system = nil
    end

    puts "\n\u001b[31;1m◉\u001b[0m app/consumers/compliance_consumer.rb#consume_one"
    puts "system: #{system}"
    puts "policy: #{policy}"
    puts "message: #{message}"
    puts "message.payload: #{message.payload}"
    puts "-" * 40

    if policy.present? && system.present?
      logger.info "Assigning System #{system} to Policy #{policy}"
      # V2::SystemsController.new.update => new_policy_system
    end
  end
end
