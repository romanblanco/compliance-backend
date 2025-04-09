# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ComplianceConsumer do
  subject(:consumer) { karafka.consumer_for(Settings.kafka.topics.inventory_events) }

  let(:payload) do
    {
      'type' => type,
      'host' => {
        'id' => system.id,
        'facts' => { 'image_builder' => { 'compliance_policy_id' => policy.id } },
        'timestamp' => DateTime.now.iso8601(6),
        'org_id' => org_id # NOTE: in the case of host deletion `org_id` is on the top level
      },
      'platform_metadata' => {
        'service' => service,
        'b64_identity' => current_user.account.b64_identity, # TODO: by default, we should not give access
        'request_id' => 1
      }
    }
  end

  before do
    V2::ApplicationPolicy.instance_variable_set(:@user, current_user)
    karafka.produce(payload.to_json)
  end

  let(:current_user) { FactoryBot.create(:v2_user, :with_cert_auth) }
  let(:org_id) { current_user.org_id }
  let(:system) { FactoryBot.create(:system, account: current_user.account) }
  let(:policy) { FactoryBot.create(:v2_policy, account: current_user.account) }

  describe 'when create message is received' do
    let(:type) { 'created' }
    let(:service) { 'compliance' }

    it 'processes host assignment to a policy' do
      expect(Karafka.logger).to receive(:info).with("Received message")

      consumer.consume
    end
  end
end
