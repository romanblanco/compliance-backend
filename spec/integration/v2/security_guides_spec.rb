# frozen_string_literal: true

require 'openapi_helper'

describe 'Security Guides', openapi_spec: 'v2/openapi.json' do
  let(:request_headers) { { 'X-RH-IDENTITY' => FactoryBot.create(:v2_user).account.identity_header.raw } }

  before { stub_rbac_permissions(Rbac::COMPLIANCE_ADMIN, Rbac::INVENTORY_HOSTS_READ) }

  path '/security_guides' do
    before { FactoryBot.create_list(:v2_security_guide, 25) }

    get 'Request Security Guides' do
      v2_auth_header
      tags 'Content'
      description 'Retrieve a list of all SCAP security guides.'
      operationId 'SecurityGuides'
      content_types
      pagination_params_v2
      ids_only_param
      sort_params_v2(V2::SecurityGuide)
      search_params_v2(V2::SecurityGuide)

      response '200', 'Lists Security Guides' do
        v2_collection_schema 'security_guide'

        after { |e| autogenerate_examples(e, 'List of Security Guides') }

        run_test!
      end

      response '200', 'Lists Security Guides' do
        let(:request_params) do
          {
            'sort_by' => ['os_major_version']
          }
        end
        v2_collection_schema 'security_guide'

        after { |e| autogenerate_examples(e, 'List of Security Guides sorted by "os_major_version:asc"') }

        run_test!
      end

      response '200', 'Lists Security Guides' do
        let(:request_params) do
          {
            'filter' => '(os_major_version=8)'
          }
        end
        v2_collection_schema 'security_guide'

        after { |e| autogenerate_examples(e, 'List of Security Guides filtered by "(os_major_version=8)"') }

        run_test!
      end

      response '422', 'Returns with Unprocessable Content' do
        let(:request_params) do
          {
            'sort_by' => ['description']
          }
        end
        schema ref_schema('errors')

        after { |e| autogenerate_examples(e, 'Description of an error when sorting by incorrect parameter') }

        run_test!
      end

      response '422', 'Returns with Unprocessable Content' do
        let(:request_params) do
          {
            'limit' => 103
          }
        end
        schema ref_schema('errors')

        after { |e| autogenerate_examples(e, 'Description of an error when requesting higher limit than supported') }

        run_test!
      end
    end
  end

  path '/security_guides/os_versions' do
    before { FactoryBot.create_list(:v2_security_guide, 25) }

    get 'Request the list of available OS versions' do
      v2_auth_header
      tags 'Content'
      description 'This feature is exclusively used by the frontend'
      operationId 'SecurityGuidesOS'
      content_types
      deprecated true
      search_params_v2(V2::System)

      response '200', 'Lists available OS versions' do
        schema(type: :array, items: { type: 'integer' })

        after { |e| autogenerate_examples(e, 'List of available OS versions') }

        run_test!
      end
    end
  end

  path '/security_guides/{security_guide_id}' do
    let(:item) { FactoryBot.create(:v2_security_guide) }

    get 'Request a Security Guide' do
      v2_auth_header
      tags 'Content'
      description 'Retrieve a specific security guide.'
      operationId 'SecurityGuide'
      content_types

      parameter name: :security_guide_id, in: :path, type: :string, required: true

      response '200', 'Returns a Security Guide' do
        let(:request_params) do
          {
            'security_guide_id' => item.id
          }
        end
        v2_item_schema('security_guide')

        after { |e| autogenerate_examples(e, 'Returns a Security Guide') }

        run_test!
      end

      response '404', 'Returns with Not Found' do
        let(:request_params) do
          {
            'security_guide_id' => Faker::Internet.uuid
          }
        end
        schema ref_schema('errors')

        after { |e| autogenerate_examples(e, 'Description of an error when requesting a non-existing Security Guide') }

        run_test!
      end
    end
  end

  path '/security_guides/{security_guide_id}/rule_tree' do
    let(:item) { FactoryBot.create(:v2_security_guide, rule_count: 10) }

    get 'Request the Rule Tree of a Security Guide' do
      v2_auth_header
      tags 'Content'
      description 'Returns rule tree of a security guide.'
      operationId 'SecurityGuideRuleTree'
      content_types
      deprecated true

      parameter name: :security_guide_id, in: :path, type: :string, required: true

      response '200', 'Returns the Rule Tree of a Security Guide' do
        let(:request_params) do
          {
            'security_guide_id' => item.id
          }
        end
        schema ref_schema('rule_tree')

        after { |e| autogenerate_examples(e, 'Returns the Rule Tree of a Security Guide') }

        run_test!
      end

      response '404', 'Returns with Not Found' do
        let(:request_params) do
          {
            'security_guide_id' => Faker::Internet.uuid
          }
        end
        schema ref_schema('errors')

        after { |e| autogenerate_examples(e, 'Description of an error when requesting a non-existing Security Guide') }

        run_test!
      end
    end
  end
end
