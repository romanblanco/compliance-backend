# frozen_string_literal: true

require 'rails_helper'

describe Kafka::PolicySystemImporter do
  let(:service) { Kafka::PolicySystemImporter.new(message, Karafka.logger) }

  let(:type) { 'create' }
  let(:policy) { FactoryBot.create(:v2_policy) }
  let(:user) { FactoryBot.create(:v2_user) }
  let(:org_id) { user.org_id }
  let(:system) do
    FactoryBot.create(
      :system,
      account: user.account
    )
  end
  let(:message) do
    {
      'type' => type,
      'timestamp' => DateTime.now.iso8601(6),
      'host' => {
        'id' => system.id,
        'org_id' => org_id,
        'image_builder' => {
          'compliance_policy_id' => policy.id
        }
      }
    }
  end

  # it 'imports PolicySystem' do
  #   expect(V2::PolicySystem).to receive(:new).with(
  #     policy_id: policy.id,
  #     system_id: system.id
  #   ).and_return(instance_double(V2::PolicySystem, save!: true))

  #   expect(Karafka.logger).to receive(:audit_success).with(
  #     "[#{org_id}] Imported PolicySystem for System #{system.id}"
  #   )

  #   service.import
  # end

  context 'received invalid system ID' do
    let(:message) do
      super().deep_merge(
        {
          'host' => {
            'id' => system.id.gsub(/\d/, '9')
          }
        }
      )
    end

    # it 'handles and logs exception' do
    #   expect(Karafka.logger).to receive(:audit_fail).with(
    #     "[#{org_id}] Failed to import PolicySystem: System not found"
    #   )

    #   expect { service.import }.to raise_error(ActiveRecord::RecordNotFound).with_message(
    #     'System not found'
    #   )
    # end
  end

  context 'received invalid policy ID' do
    let(:message) do
      super().deep_merge(
        {
          'host' => {
            'facts' => {
              'image_builder' => {
                'compliance_policy_id' => policy.id.gsub(/\d/, '9')
              }
            }
          }
        }
      )
    end

    # it 'handles and logs exception' do
    #   expect(Karafka.logger).to receive(:audit_fail).with(
    #     "[#{org_id}] Failed to import PolicySystem: Policy not found"
    #   )

    #   expect { service.import }.to raise_error(ActiveRecord::RecordNotFound).with_message(
    #     'Policy not found'
    #   )
    # end
  end
end
