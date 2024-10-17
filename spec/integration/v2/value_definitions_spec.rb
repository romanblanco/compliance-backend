# frozen_string_literal: true

require 'openapi_helper'

describe 'Value Definitions', openapi_spec: 'v2/openapi.json' do
  let(:request_headers) { { 'X-RH-IDENTITY' => FactoryBot.create(:v2_user).account.identity_header.raw } }

  before { stub_rbac_permissions(Rbac::COMPLIANCE_ADMIN, Rbac::INVENTORY_HOSTS_READ) }

  path '/security_guides/{security_guide_id}/value_definitions' do
    before { FactoryBot.create_list(:v2_value_definition, 25, security_guide_id: security_guide_id) }

    let(:security_guide_id) { FactoryBot.create(:v2_security_guide).id }

    get 'Request Value Definitions' do
      v2_auth_header
      tags 'Content'
      description 'Retrieve a list of the fields which can be edited within a profile.'
      operationId 'ValueDefinitions'
      content_types
      pagination_params_v2
      ids_only_param
      sort_params_v2(V2::ValueDefinition)
      search_params_v2(V2::ValueDefinition)

      parameter name: :security_guide_id, in: :path, type: :string, required: true

      response '200', 'Lists Value Definitions' do
        let(:request_params) do
          {
            'security_guide_id' => security_guide_id
          }
        end
        v2_collection_schema 'value_definition'

        after { |e| autogenerate_examples(e, 'List of Value Definitions') }

        run_test!
      end

      response '200', 'Lists Value Definitions' do
        let(:request_params) do
          {
            'sort_by' => ['title'],
            'security_guide_id' => security_guide_id
          }
        end
        v2_collection_schema 'value_definition'

        after { |e| autogenerate_examples(e, 'List of Value Definitions sorted by "title:asc"') }

        run_test!
      end

      response '200', 'Lists Value Definitions' do
        let(:request_params) do
          {
            'filter' => "(title=\"#{V2::ValueDefinition.first.title}\")",
            'security_guide_id' => security_guide_id
          }
        end
        v2_collection_schema 'value_definition'

        after do |e|
          autogenerate_examples(e, "List of Value Definitions filtered by '(title=#{V2::ValueDefinition.first.title})'")
        end

        run_test!
      end

      response '422', 'Returns with Unprocessable Content' do
        let(:request_params) do
          {
            'sort_by' => ['description'],
            'security_guide_id' => security_guide_id
          }
        end
        schema ref_schema('errors')

        after { |e| autogenerate_examples(e, 'Description of an error when sorting by incorrect parameter') }

        run_test!
      end

      response '422', 'Returns with Unprocessable Content' do
        let(:request_params) do
          {
            'limit' => 103,
            'security_guide_id' => security_guide_id
          }
        end
        schema ref_schema('errors')

        after { |e| autogenerate_examples(e, 'Description of an error when requesting higher limit than supported') }

        run_test!
      end
    end
  end

  path '/security_guides/{security_guide_id}/value_definitions/{value_definition_id}' do
    let(:item) { FactoryBot.create(:v2_value_definition) }

    get 'Request a Value Definition' do
      v2_auth_header
      tags 'Content'
      description 'Retrieve a specific value definition.'
      operationId 'ValueDefinition'
      content_types

      parameter name: :security_guide_id, in: :path, type: :string, required: true
      parameter name: :value_definition_id, in: :path, type: :string, required: true

      response '200', 'Returns a Value Definition' do
        let(:request_params) do
          {
            'value_definition_id' => item.id,
            'security_guide_id' => item.security_guide.id
          }
        end
        v2_item_schema('value_definition')

        after { |e| autogenerate_examples(e, 'Returns a Value Definition') }

        run_test!
      end

      response '404', 'Returns with Not Found' do
        let(:request_params) do
          {
            'value_definition_id' => Faker::Internet.uuid,
            'security_guide_id' => Faker::Internet.uuid
          }
        end
        schema ref_schema('errors')

        after do |e|
          autogenerate_examples(e, 'Description of an error when requesting a non-existing Value Definition')
        end

        run_test!
      end
    end
  end
end
