# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ParseReport do
  subject(:consumer) { karafka.consumer_for(Settings.kafka.topics.inventory_events) }

  let(:current_user) { FactoryBot.create(:v2_user) }
  let(:org_id) { current_user.org_id }
  let(:url) { "/tmp/uploads/insights-upload-quarantine/#{Faker::Alphanumeric.alphanumeric(number: 21)}" }
  let(:request_id) { Faker::Alphanumeric.alphanumeric(number: 32) }
  let(:b64_identity) { Faker::Internet.base64(length: 64) }
  let(:system) do
    FactoryBot.create(
      :system,
      account: current_user.account,
    )
  end

  let(:payload) do
    # TODO: by default, we should not test with user with access, so
    #       current_user.account.b64_identity shall be used, as it poionts to fake_identity_header
    #       otherwise for valid identity header, use current_user.account.identity_header.raw
    {
      'host' => {
        'id' => system.id,
        'facts' => [],
        'timestamp' => DateTime.now.iso8601(6),
        'org_id' => org_id
      },
      'platform_metadata' => {
        'org_id' => org_id,
        'request_id' => Faker::Alphanumeric.alphanumeric(number: 32),
        'url' => url,
        'b64_identity' => current_user.account.b64_identity,
      }
    }
  end

  before do
    #V2::ApplicationPolicy.instance_variable_set(:@user, current_user)
    karafka.produce(payload.to_json)
  end

  describe 'when message for parsing reports is received' do
    context 'with failing entitlement check' do
      it 'results in rejecting processing the report' do
        expect(Karafka.logger).to receive(:info).with("Received message")

        consumer.consume
      end
    end

    context 'with empty reports content' do
      it 'results in rejecting in parsing the reports' do
        #
      end
    end

    context 'with unparsable report' do
      it 'results in raising parse error' do
        #
      end
    end

    context 'with parsable reports' do
      context 'with previously succeeding scan' do
        #
      end

      context 'succeeding scan' do
        #
      end
    end
  end
end
