# frozen_string_literal: true

require 'rails_helper'

RSpec.describe InventoryEventsConsumer do
  # This will create a consumer instance with all the settings defined for the given topic
  subject(:consumer) { karafka.consumer_for('validation') }

  let(:nr1_value) { rand }
  let(:nr2_value) { rand }
  let(:sum) { nr1_value + nr2_value }

  before do
    # Sends first message to Karafka consumer
    karafka.produce({ 'type' => 'delete' }.to_json)

    allow(Karafka.logger).to receive(:info)
  end

  it 'expects to log a proper message' do
    expect(Karafka.logger).to receive(:info).with("Sum of 2 elements equals to: #{sum}")
    consumer.consume_one
  end
end
