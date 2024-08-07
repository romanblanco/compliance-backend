# frozen_string_literal: true

require 'test_helper'

class RuleReferencesContainersTest < ActiveSupport::TestCase
  class Mock
    include Xccdf::Profiles
    include Xccdf::Rules
    include Xccdf::RuleGroups
    include Xccdf::ValueDefinitions
    include Xccdf::RuleReferencesContainers

    attr_accessor :benchmark, :account, :op_profiles, :op_rules

    def initialize(report_contents)
      test_result_file = OpenscapParser::TestResultFile.new(report_contents)
      @op_benchmark = test_result_file.benchmark
      @op_test_result = test_result_file.test_result
      @op_rules = @op_benchmark.rules
      @op_profiles = @op_benchmark.profiles
      @op_rule_groups = @op_benchmark.groups
      @op_value_definitions = @op_benchmark.values
    end
  end

  setup do
    @mock = Mock.new(file_fixture('xccdf_report.xml').read)
    @mock.benchmark = FactoryBot.create(
      :canonical_profile, :with_rules
    ).benchmark
    @mock.account = FactoryBot.create(:account)
    @mock.save_rule_groups
    @mock.save_value_definitions
    @mock.save_rules
  end

  test 'save all rule references containers as new' do
    assert_difference('RuleReferencesContainer.count', 367) do
      @mock.save_rule_references_containers
    end
  end

  test 'returns rule references containers saved in the report' do
    rrc = RuleReferencesContainer.from_openscap_parser(@mock.op_rules.first,
                                                       rule_id: @mock.rules.first.id)
    assert rrc.save
    @mock.save_rule_references_containers
    assert_includes @mock.rule_references_containers, rrc
  end

  test 'updates rule_references field when needed' do
    @mock.save_rule_references_containers

    rule = @mock.rules.first

    @mock.instance_variable_set(:@rule_references_containers, nil)
    @mock.instance_variable_set(:@old_rule_references_containers, nil)
    @mock.instance_variable_set(:@new_rule_references_containers, nil)
    @mock.instance_variable_get(:@op_rules).first.stubs(:references).returns([{ foo: 'bar' }])
    @mock.save_rule_references_containers

    assert_equal RuleReferencesContainer.find_by(rule_id: rule.id).rule_references, [{ 'foo' => 'bar' }]
  end
end
