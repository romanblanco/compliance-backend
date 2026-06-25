# frozen_string_literal: true

# Patch for https://github.com/Fullscript/yabeda-activejob/pull/26
#
# Once that PR is merged and a new gem version is released:
#   1. Delete this file.
#   2. In Gemfile, bump yabeda-activejob to the version that includes the PR.
#   3. Run `bundle install` to update Gemfile.lock.

require 'yabeda/activejob'
require 'yabeda/activejob/event_handler'

module Yabeda
  module ActiveJob
    def self.custom_tags(job)
      return {} unless job.respond_to?(:yabeda_tags)

      if job.method(:yabeda_tags).arity.zero?
        job.yabeda_tags
      else
        job.yabeda_tags(*job.arguments)
      end
    end
  end
end

Yabeda::ActiveJob::EventHandler.prepend(Module.new do
  # In 0.6.0, handle_perform builds labels inline instead of via common_labels,
  # so perform metrics miss both default_tags and custom_tags. Override to fix both.
  def handle_perform
    labels = common_labels(event.payload[:job])

    if event.payload[:exception].present?
      Yabeda.activejob_failed_total.increment(
        labels.merge(failure_reason: event.payload[:exception].first.to_s)
      )
    else
      Yabeda.activejob_success_total.increment(labels)
    end

    Yabeda.activejob_executed_total.increment(labels)
    Yabeda.activejob_runtime.measure(labels, ms2s(event.duration))
    call_after_event_block
  end

  private

  def common_labels(job)
    super.merge(Yabeda::ActiveJob.custom_tags(job))
  end
end)
