# frozen_string_literal: true

module Xccdf
  # Methods related to finding Tailorings
  module Tailorings
    # rubocop:disable Rails/FindByOrAssignmentMemoization
    def tailoring
      @tailoring ||= begin
        minor = Settings.consider_os_minor_versions == false ? 0 : @system.os_minor_version.to_i
        ::Tailoring.find_by(policy: @policy, os_minor_version: minor)
      end
    end
    # rubocop:enable Rails/FindByOrAssignmentMemoization

    def external_report?
      @policy.nil?
    end

    def tailored_profile
      unless tailoring
        raise ::XccdfReportParser::OSVersionMismatch,
              "No tailoring found for policy #{@policy&.id} and OS minor version " \
              "#{@system.os_minor_version}. The system OS version may have changed " \
              'after policy assignment.'
      end

      @tailored_profile ||= tailoring.profile
    end
  end
end
