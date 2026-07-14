# frozen_string_literal: true

require 'rails_helper'

describe Tailoring do
  describe '.for_policy' do
    let(:policy) { FactoryBot.create(:policy, :for_tailoring, supports_minors: [0]) }

    context 'when consider_os_minor_versions is false' do
      before { allow(Settings).to receive(:consider_os_minor_versions).and_return(false) }

      it 'normalizes os_minor_version to 0' do
        tailoring = described_class.for_policy(policy, 4)

        expect(tailoring.os_minor_version).to eq(0)
      end
    end

    it 'uses the requested os_minor_version when toggle is true' do
      tailoring = described_class.for_policy(policy, 0)

      expect(tailoring.os_minor_version).to eq(0)
    end
  end

  describe '#value_overrides_by_ref_id' do
    subject do
      FactoryBot.create(
        :tailoring,
        :with_tailored_values,
        policy: FactoryBot.create(:policy, :for_tailoring, supports_minors: [0]),
        os_minor_version: 0
      )
    end

    it 'indexes overrides by ref_id' do
      expect(subject.value_overrides_by_ref_id).not_to be_empty

      expect(
        subject.security_guide.value_definitions.where(ref_id: subject.value_overrides_by_ref_id.keys)
      ).not_to be_empty
    end
  end
end
