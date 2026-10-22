# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MemoryDiagnostics do
  around do |example|
    previous = ENV.values_at('MEMORY_DEBUG', 'MEMORY_DEBUG_SAMPLE_RATE')
    ENV['MEMORY_DEBUG'] = 'true'
    ENV['MEMORY_DEBUG_SAMPLE_RATE'] = '1.0'
    example.run
  ensure
    ENV['MEMORY_DEBUG'], ENV['MEMORY_DEBUG_SAMPLE_RATE'] = previous
  end

  describe '.measure' do
    it 'logs memory and GC snapshots' do
      expect(Rails.logger).to receive(:info).with(a_string_starting_with('memory_debug '))

      expect(described_class.measure('test_event', value: 1) { :result }).to eq(:result)
    end
  end

  describe '.event' do
    it 'does not log when disabled' do
      ENV['MEMORY_DEBUG'] = 'false'
      expect(Rails.logger).not_to receive(:info)

      described_class.event('test_event')
    end
  end
end
