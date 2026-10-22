# frozen_string_literal: true

require 'json'

# Opt-in diagnostics for investigating Ruby process memory growth.
module MemoryDiagnostics
  SAMPLE_RATE_ENV = 'MEMORY_DEBUG_SAMPLE_RATE'
  ENABLED_ENV = 'MEMORY_DEBUG'
  GC_KEYS = %i[
    heap_live_slots
    heap_free_slots
    old_objects
    total_allocated_objects
    malloc_increase_bytes
    oldmalloc_increase_bytes
    major_gc_count
    minor_gc_count
  ].freeze

  module_function

  def enabled?
    ActiveModel::Type::Boolean.new.cast(ENV.fetch(ENABLED_ENV, 'false'))
  end

  def measure(label, fields = {})
    return yield unless enabled? && sampled?

    started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    before = snapshot

    begin
      yield
    ensure
      log_measurement(label, fields, started_at, before)
    end
  end

  def event(label, fields = {})
    return unless enabled? && sampled?

    log(label, fields.merge(snapshot: snapshot))
  end

  def snapshot
    GC.stat.slice(*GC_KEYS).merge(rss_kb: rss_kb, pid: Process.pid)
  end

  def sampled?
    rate = Float(ENV.fetch(SAMPLE_RATE_ENV, '1.0'))
    rate >= 1.0 || (rate.positive? && rand < rate)
  rescue ArgumentError
    true
  end

  def log(label, fields)
    Rails.logger.info("memory_debug #{JSON.generate(event: label, **fields)}")
  end

  def log_measurement(label, fields, started_at, before)
    log(
      label,
      fields.merge(
        duration_ms: elapsed_ms(started_at),
        before: before,
        after: snapshot
      )
    )
  end

  def elapsed_ms(started_at)
    ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000).round(2)
  end

  def rss_kb
    File.foreach('/proc/self/status') do |line|
      return line.split[1].to_i if line.start_with?('VmRSS:')
    end
  rescue Errno::ENOENT, Errno::EACCES
    nil
  end
end
