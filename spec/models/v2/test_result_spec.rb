# frozen_string_literal: true

require 'rails_helper'

describe V2::TestResult do
  describe '.os_versions' do
    let(:versions) { ['7.1', '7.2', '7.3'] }

    let(:account) { FactoryBot.create(:account) }

    let(:policy) do
      FactoryBot.create(:v2_policy, os_major_version: 7, supports_minors: [1, 2, 3], account: account)
    end

    before do
      versions.each do |version|
        major, minor = version.split('.')
        FactoryBot.create_list(
          :system, (1..10).to_a.sample,
          os_major_version: major.to_i,
          os_minor_version: minor.to_i,
          policy_id: policy.id,
          account: account
        ).each do |sys|
          FactoryBot.create(:v2_test_result, system: sys, policy_id: policy.id)
        end
      end
    end

    subject { described_class.where.associated(:system) }

    it 'returns a unique and sorted set of all versions' do
      expect(subject.os_versions.to_set { |version| version.delete('"') }).to eq(versions.to_set)
    end

    context 'query optimization' do
      it 'strips aggregation joins to prevent duplicate table scans' do
        fake_table = Arel::Table.new('nonexistent_test_table')
        join_condition = fake_table[:id].eq(described_class.arel_table[:id])
        aggregation_join = fake_table.create_join(fake_table, fake_table.create_on(join_condition))

        scope_with_aggregation = subject.joins(aggregation_join)

        captured_sql = []
        subscriber = ActiveSupport::Notifications.subscribe('sql.active_record') do |*, payload|
          captured_sql << payload[:sql] if payload[:sql].include?('CONCAT')
        end

        scope_with_aggregation.os_versions
        ActiveSupport::Notifications.unsubscribe(subscriber)

        query = captured_sql.first
        expect(query).not_to include('nonexistent_test_table')
        expect(query.scan('"inventory"."hosts"').count).to eq(1)
      end
    end
  end

  describe '#compliant' do
    let(:account) { FactoryBot.create(:v2_account) }
    let(:policy) do
      FactoryBot.create(
        :v2_policy,
        :for_tailoring,
        account: account,
        compliance_threshold: threshold,
        os_major_version: 7,
        supports_minors: [0]
      )
    end
    let(:test_result) do
      FactoryBot.create(
        :v2_test_result,
        policy_id: policy.id,
        account: account,
        score: score
      )
    end

    context 'score comparison' do
      let(:threshold) { 90.0 }

      context 'when score > threshold' do
        let(:score) { 90.01 }

        it 'reports compliant' do
          expect(test_result.compliant).to eq(true)
        end
      end

      context 'when score == threshold' do
        let(:score) { 90.0 }

        it 'reports compliant' do
          expect(test_result.compliant).to eq(true)
        end
      end

      context 'score == threshold' do
        let(:score) { 90.0 }

        it 'returns true when score equals threshold' do
          expect(test_result.compliant).to eq(true)
        end
      end

      context 'when score < threshold' do
        let(:score) { 89.99 }

        it 'reports non-compliant' do
          allow(test_result).to receive(:report).and_return(policy)
          expect(test_result.compliant).to eq(false)
        end
      end
    end

    context 'threshold changes' do
      let(:threshold) { 95.0 }
      let(:score) { 90.0 }

      it 'threshold change updates compliant status' do
        allow(test_result).to receive(:report).and_return(policy)
        expect(test_result.compliant).to eq(false)

        policy.update!(compliance_threshold: 85.0)
        test_result.reload
        expect(test_result.compliant).to eq(true)
      end
    end

    context 'nil score' do
      let(:threshold) { 90.0 }
      let(:score) { nil }

      it 'returns false when score is nil' do
        expect(test_result.compliant).to eq(false)
      end
    end
  end
end
