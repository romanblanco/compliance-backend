# frozen_string_literal: true

module Xccdf
  # Methods related to finding Tailorings
  module Tailorings
    # rubocop:disable Rails/FindByOrAssignmentMemoization
    def tailoring
      @tailoring ||= begin
        minor = ::SupportedSsg.resolve_minor(@system.os_major_version, @system.os_minor_version)
        ::Tailoring.find_by(policy: @policy, os_minor_version: minor)
      end
    end
    # rubocop:enable Rails/FindByOrAssignmentMemoization

    def external_report?
      @policy.nil?
    end

    def tailored_profile
      unless tailoring
        resolved = ::SupportedSsg.resolve_minor(@system.os_major_version, @system.os_minor_version)
        raise ::XccdfReportParser::OSVersionMismatch,
              "No tailoring found for policy #{@policy&.id} and OS minor version " \
              "#{@system.os_minor_version} (resolved to #{resolved}). The system OS version " \
              'may have changed after policy assignment.'
      end

      @tailored_profile ||= tailoring.profile
    end
  end
end
