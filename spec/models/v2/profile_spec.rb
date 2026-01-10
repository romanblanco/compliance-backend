# frozen_string_literal: true

require 'rails_helper'

describe V2::Profile do
  describe '#variant_for_minor' do
    let(:subject) { FactoryBot.create(:v2_profile) }

    context 'single variant' do
      let!(:result) do
        FactoryBot.create(
          :v2_profile,
          ref_id: subject.ref_id,
          supports_minors: [0],
          security_guide: FactoryBot.create(:v2_security_guide, version: '0.1.0')
        )
      end

      it 'returns with the only one' do
        expect(subject.variant_for_minor(0)).to eq(result)
      end
    end

    context 'multiple variants' do
      let!(:result) do
        FactoryBot.create(
          :v2_profile,
          ref_id: subject.ref_id,
          supports_minors: [0],
          security_guide: FactoryBot.create(:v2_security_guide, version: '0.1.0')
        )
      end

      before do
        3.times do |i|
          FactoryBot.create(
            :v2_profile,
            ref_id: subject.ref_id,
            supports_minors: [0],
            security_guide: FactoryBot.create(:v2_security_guide, version: "0.0.#{i}")
          )
        end
      end

      it 'returns with the latest' do
        expect(subject.variant_for_minor(0)).to eq(result)
      end
    end

    context 'no variant' do
      it 'raises an error' do
        expect { subject.variant_for_minor(0) }.to raise_exception(Exceptions::OSMinorVersionNotSupported)
      end
    end

    context 'upstream mode (minor versions disabled)' do
      let!(:profile_v1) do
        FactoryBot.create(
          :v2_profile,
          ref_id: subject.ref_id,
          supports_minors: [1],
          security_guide: FactoryBot.create(:v2_security_guide, version: '0.1.0')
        )
      end

      let!(:profile_v2) do
        FactoryBot.create(
          :v2_profile,
          ref_id: subject.ref_id,
          supports_minors: [2],
          security_guide: FactoryBot.create(:v2_security_guide, version: '0.2.0')
        )
      end

      before do
        allow(Settings).to receive(:consider_os_minor_versions).and_return(false)
      end

      it 'returns latest profile for major version regardless of minor version' do
        # Should return the latest version (v0.2.0) even when asking for minor version 1
        expect(subject.variant_for_minor(1)).to eq(profile_v2)
        expect(subject.variant_for_minor(2)).to eq(profile_v2)
        expect(subject.variant_for_minor(999)).to eq(profile_v2)
      end
    end
  end
end
