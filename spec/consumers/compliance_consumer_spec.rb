# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ComplianceConsumer do
  subject(:consumer) { karafka.consumer_for(Settings.kafka.topics.inventory_events) }

  let(:payload) do
    # TODO: by default, we should not test with user with access, so
    #       current_user.account.b64_identity shall be used, as it poionts to fake_identity_header
    #       otherwise for valid identity header, use current_user.account.identity_header.raw
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
        'b64_identity' => current_user.account.identity_header.raw, # FIXME: too permisive for default
        'request_id' => Faker::Alphanumeric.alphanumeric(number: 32)
      }
    }
  end

  before do
    #V2::ApplicationPolicy.instance_variable_set(:@user, current_user)
    karafka.produce(payload.to_json)
  end

  let(:current_user) { FactoryBot.create(:v2_user, :with_cert_auth) }
  let(:org_id) { current_user.org_id }
  let(:system) { FactoryBot.create(:system, account: current_user.account) }
  let(:policy) { FactoryBot.create(:v2_policy, account: current_user.account) }

  describe 'when message for parsing report is received' do
    let(:type) { 'created' }
    let(:service) { 'compliance' }

    it 'ReportParser concern is called' do
      expect(Karafka.logger).to receive(:info).with("Received message")

      consumer.consume
    end
  end

  describe 'when message about created host is received' do
    # let(:'X-RH-IDENTITY') { current_user.account.identity_header.raw }
  end
end
