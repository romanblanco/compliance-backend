# frozen_string_literal: true

# Consumer concerns related to report parsing
module ParseReport
  # Raise an error if entitlement is not available
  class EntitlementError < StandardError; end
  # Raise an error if parsing report is not possible
  class ReportParseError < StandardError; end

  # TODO: consider creating Report class with attribute 'profile' and 'raw'
  #       to encapsulate methods working with parsed report
  #
  #       ParsedReport
  #       ---
  #       + profile
  #       + raw
  #       ---
  #       + process
  #       - report_compliant?
  #       - allows_notification? # why should we need to store it before 'report.save_all'

  def parse_reports
    raise EntitlementError unless identity.valid?
    raise ReportParseError if reports.empty?

    # Map successfuly parsed (validated) reports by scanned profile
    parsed_reports = reports.map do |raw|
      parsed = parse(raw)
      [parsed.test_result_file.test_result.profile_id, raw]
    end

    # Evaluate each report individually and notify abut the result
    parsed_reports.each do |profile, report|
      process_report(profile, report)
    end
  end

  private

  def reports
    @reports ||= SafeDownloader.download_reports(url, ssl_only: Settings.report_download_ssl_only)
  rescue SafeDownloader::DownloadError => e
    parse_error(e)
  end

  def url
    message.payload.dig('platform_metadata', 'url')
  end

  def parse(raw)
    XccdfReportParser.new(raw, message)
  rescue PG::Error, ActiveRecord::StatementInvalid => e
    parse_error(e)
  rescue StandardError
    raise ReportParseError
  end

  def process_report(profile, report)
    logger.info "Processing #{profile} report #{report}"

    # Storing notification preconditions before saving the report
    should_notify = notifications_allowed?(report)

    # Evaluate compliance of the report
    if report_compliant?(report)
      report.save_all
    else
      if should_notify
        logger.info('Emitting notification due to non-compliance')
        notify_non_compliant!
      end
    end

    notify_remediation(report)
    parse_success(report, profile)
  end

  def report_compliant?(report)
    report.supported? && report.score >= report.policy.compliance_threshold
  end

  def notifications_allowed?(report)
    previously_compliant = report.policy&.compliant?(report.system)
    no_test_results = report.policy&.test_result_systems&.where(id: report.system.id)&.empty?

    previously_compliant || no_test_results
  end

  def notify_non_compliant!(report)
    SystemNonCompliant.deliver(
      system: report.system,
      org_id: message['org_id'],
      policy: report.policy,
      policy_threshold: report.policy.compliance_threshold,
      compliance_score: report.score
    )
  end

  def notify_remediation(report)
    RemediationUpdates.deliver(
      system_id: message['id'],
      issue_ids: remediation_issue_ids(report)
    )
  end

  def remediation_issue_ids(report)
    report.failed_rules
          .includes(profiles: :benchmark)
          .collect(&:remediation_issue_id)
          .compact
  end

  def parse_success(report, profile)
    msg = "[#{org_id}] Successfull report of #{profile} " \
          "for policy #{report.system_profile.policy_id} " \
          "from system #{message['id']}"
    logger.audit_success msg
    produce_validation_message('success')
  end

  def parse_error(exception)
    msg = "[#{org_id}] #{exception_message(exception)}"
    logger.error msg
    logger.audit_fail msg
    produce_validation_message('failed')
  end

  def produce_validation_message(result)
    # TODO: send this message to validation topic, if present
    {
      'request_id': request_id,
      'service': 'compliance',
      'validation': result
    }
  end

  def exception_message(e)
    case e
    when EntitlementError
      "Rejected report with request id #{request_id}: invalid identity or missing insights entitlement"
    when SafeDownloader::DownloadError
      "Failed to dowload report with request id #{request_id}: #{e.message}"
    when ReportParseError
      "Invalid report: #{e.cause.message}"
    else
      "Error parsing report: #{request_id} - #{e.message}"
    end
  end
end
