# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ComplianceConsumer do
  let(:message) do
    {
      'type' => type,
      'host' => {
        'id' => system.id,
        'facts' => { 'image_builder' => { 'compliance_policy_id' => policy.id } },
        'timestamp' => DateTime.now.iso8601(6),
        'org_id' => org_id # NOTE: in the case of host deletion `org_id` is on the top level
      }
    }
  end

  before do
    V2::ApplicationPolicy.instance_variable_set(:@user, current_user)
    karafka.produce(message.to_json)
  end

  subject(:consumer) { karafka.consumer_for(Settings.kafka.topics.inventory_events) }

  let(:current_user) { FactoryBot.create(:v2_user) }
  let(:org_id) { current_user.org_id }
  let(:system) { FactoryBot.create(:system, account: current_user.account) }
  let(:policy) { FactoryBot.create(:v2_policy, account: current_user.account) }

  describe 'when create message is received' do
    let(:type) { 'created' }

    it 'processes host assignment to a policy' do
      expect(Karafka.logger).to receive(:info).with("Received message, processing: #{message}")

      consumer.consume
    end
  end
end
