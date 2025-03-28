# frozen_string_literal: true

require 'test_helper'

module Insights
  module Api
    module Common
      class HostInventoryTest < ActiveSupport::TestCase
        setup do
          account = FactoryBot.create(:account)
          @host = FactoryBot.create(
            :host,
            org_id: account.org_id
          )

          @inventory_host = { 'id' => @host.id,
                              'display_name' => @host.name,
                              'org_id' => @host.org_id }
          @account = @host.account_object
          @b64_identity = '1234abcd'
          @api = HostInventory.new(b64_identity: @b64_identity)
          @connection = mock('faraday_connection')
          Platform.stubs(:connection).returns(@connection)
        end

        test 'works with nil b64_identity' do
          api = HostInventory.new(account: @account, b64_identity: nil)
          assert_equal @account.b64_identity,
                       api.instance_variable_get(:@b64_identity)
        end

        test 'hosts queries inventory hosts endpoint' do
          response = OpenStruct.new(body: { results: [@inventory_host] }.to_json)
          @connection.expects(:get).returns(response)

          assert_includes @api.hosts.dig('results').map { |h| h['id'] },
                          @host.id
        end
      end
    end
  end
end
