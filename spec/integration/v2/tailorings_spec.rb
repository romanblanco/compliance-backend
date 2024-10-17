# frozen_string_literal: true

require 'openapi_helper'

describe 'Tailorings', openapi_spec: 'v2/openapi.json' do
  let(:user) { FactoryBot.create(:v2_user) }
  let(:request_headers) { { 'X-RH-IDENTITY' => user.account.identity_header.raw } }

  before { stub_rbac_permissions(Rbac::COMPLIANCE_ADMIN, Rbac::INVENTORY_HOSTS_READ) }

  path '/policies/{policy_id}/tailorings' do
    let(:canonical_profiles) do
      25.times.map do |version|
        FactoryBot.create(:v2_profile, ref_id_suffix: 'foo', supports_minors: [version])
      end
    end

    let(:policy_id) do
      FactoryBot.create(
        :v2_policy,
        account: user.account,
        profile: canonical_profiles.last
      ).id
    end

    get 'Request Tailorings' do
      v2_auth_header
      tags 'Policies'
      description 'Retrieve a list of all tailorings.'
      operationId 'Tailorings'
      content_types
      pagination_params_v2
      ids_only_param
      sort_params_v2(V2::Tailoring)
      search_params_v2(V2::Tailoring)

      before do
        25.times.map do |version|
          FactoryBot.create(
            :v2_tailoring,
            policy: V2::Policy.find(policy_id),
            os_minor_version: version
          )
        end
      end

      parameter name: :policy_id, in: :path, type: :string, required: true

      response '200', 'Lists Tailorings' do
        let(:request_params) do
          {
            'policy_id' => policy_id
          }
        end
        v2_collection_schema 'tailoring'

        after { |e| autogenerate_examples(e, 'List of Tailorings') }

        run_test!
      end

      response '200', 'Lists Tailorings' do
        let(:request_params) do
          {
            'policy_id' => policy_id,
            'sort_by' => ['os_minor_version']
          }
        end
        v2_collection_schema 'tailoring'

        after { |e| autogenerate_examples(e, 'List of Tailorings sorted by "os_minor_version:asc"') }

        run_test!
      end

      response '200', 'Lists Tailorings' do
        let(:version) { V2::Tailoring.first.os_minor_version }
        let(:request_params) do
          {
            'policy_id' => policy_id,
            'filter' => "(os_minor_version=#{version})"
          }
        end
        v2_collection_schema 'tailoring'

        after { |e| autogenerate_examples(e, "List of Tailorings filtered by '(os_minor_version=#{version})'") }

        run_test!
      end

      response '422', 'Returns with Unprocessable Content' do
        let(:request_params) do
          {
            'policy_id' => policy_id,
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
            'policy_id' => policy_id,
            'limit' => 103
          }
        end
        schema ref_schema('errors')

        after { |e| autogenerate_examples(e, 'Description of an error when requesting higher limit than supported') }

        run_test!
      end
    end

    post 'Create a Tailoring' do
      v2_auth_header
      tags 'Policies'
      description 'Create a Tailoring with the provided attributes (for ImageBuilder only)'
      operationId 'CreateTailoring'
      content_types
      deprecated true

      parameter name: :policy_id, in: :path, type: :string, required: true
      parameter name: :data, in: :body, schema: ref_schema('tailoring_create')

      response '201', 'Creates a Tailoring' do
        let(:request_params) do
          {
            'policy_id' => FactoryBot.create(
              :v2_policy,
              account: user.account,
              profile: FactoryBot.create(:v2_profile, ref_id_suffix: 'foo', supports_minors: [1])
            ).id,
            'data' => { os_minor_version: 1 }
          }
        end

        v2_item_schema('tailoring')

        after { |e| autogenerate_examples(e) }

        run_test!
      end
    end
  end

  path '/policies/{policy_id}/tailorings/{tailoring_id}' do
    let(:policy_id) do
      FactoryBot.create(
        :v2_policy,
        account: user.account,
        profile: FactoryBot.create(:v2_profile, ref_id_suffix: 'foo', supports_minors: [1])
      ).id
    end

    let(:item) do
      FactoryBot.create(:v2_tailoring, policy: V2::Policy.find(policy_id), os_minor_version: 1)
    end

    get 'Request a Tailoring' do
      v2_auth_header
      tags 'Policies'
      description 'Retrieve a specific tailoring.'
      operationId 'Tailoring'
      content_types

      parameter name: :policy_id, in: :path, type: :string, required: true
      parameter name: :tailoring_id, in: :path, type: :string, required: true,
                description: 'UUID or OS minor version number'

      response '200', 'Returns a Tailoring' do
        let(:request_params) do
          {
            'policy_id' => policy_id,
            'tailoring_id' => item.id
          }
        end
        v2_item_schema('tailoring')

        after { |e| autogenerate_examples(e, 'Returns a Tailoring') }

        run_test!
      end

      response '404', 'Returns with Not Found' do
        let(:request_params) do
          {
            'policy_id' => Faker::Internet.uuid,
            'tailoring_id' => Faker::Internet.uuid
          }
        end
        schema ref_schema('errors')

        after { |e| autogenerate_examples(e, 'Description of an error when requesting a non-existing Tailoring') }

        run_test!
      end
    end

    patch 'Update a Tailoring' do
      v2_auth_header
      tags 'Policies'
      description 'Edit or update an existing tailoring.'
      operationId 'UpdateTailoring'
      content_types

      parameter name: :policy_id, in: :path, type: :string, required: true
      parameter name: :tailoring_id, in: :path, type: :string, required: true,
                description: 'UUID or OS minor version number'
      parameter name: :data, in: :body, schema: ref_schema('tailoring')

      response '202', 'Updates a Tailoring' do
        let(:request_params) do
          {
            'policy_id' => policy_id,
            'tailoring_id' => item.id,
            'data' => {
              value_overrides: { FactoryBot.create(:v2_value_definition,
                                                   security_guide: item.security_guide).id => '123' }
            }
          }
        end
        v2_item_schema('tailoring')

        after { |e| autogenerate_examples(e, 'Returns the updated Tailoring') }

        run_test!
      end
    end
  end

  path '/policies/{policy_id}/tailorings/{tailoring_id}/rule_tree' do
    let(:policy_id) do
      FactoryBot.create(
        :v2_policy,
        account: user.account,
        profile: FactoryBot.create(:v2_profile, rule_count: 10, ref_id_suffix: 'foo', supports_minors: [1])
      ).id
    end

    let(:item) do
      FactoryBot.create(:v2_tailoring, :with_mixed_rules, policy: V2::Policy.find(policy_id), os_minor_version: 1)
    end

    get 'Request the Rule Tree of a Tailoring' do
      v2_auth_header
      tags 'Policies'
      description 'Returns rule tree of a tailoring.'
      operationId 'TailoringRuleTree'
      content_types
      deprecated true

      parameter name: :policy_id, in: :path, type: :string, required: true
      parameter name: :tailoring_id, in: :path, type: :string, required: true

      response '200', 'Returns the Rule Tree of a Tailoring' do
        let(:request_params) do
          {
            'policy_id' => policy_id,
            'tailoring_id' => item.id
          }
        end
        schema ref_schema('rule_tree')

        after { |e| autogenerate_examples(e, 'Returns the Rule Tree of a Tailoring') }

        run_test!
      end

      response '404', 'Returns with Not Found' do
        let(:request_params) do
          {
            'policy_id' => policy_id,
            'tailoring_id' => Faker::Internet.uuid
          }
        end
        schema ref_schema('errors')

        after { |e| autogenerate_examples(e, 'Description of an error when requesting a non-existing Tailoring') }

        run_test!
      end
    end
  end

  path '/policies/{policy_id}/tailorings/{tailoring_id}/tailoring_file.json' do
    let(:policy_id) do
      FactoryBot.create(:v2_policy, :for_tailoring, account: user.account, supports_minors: [1]).id
    end

    before { allow(StrongerParameters::InvalidValue).to receive(:new) { |value, _| value.to_sym } }

    let(:item) do
      FactoryBot.create(
        :v2_tailoring,
        :with_mixed_rules,
        :with_tailored_values,
        policy: V2::Policy.find(policy_id),
        os_minor_version: 1
      )
    end

    get 'Request a Tailoring file' do
      v2_auth_header
      tags 'Policies'
      description 'Retrieve a tailoring file of a specific tailoring.'
      operationId 'TailoringFile'
      content_types

      parameter name: :policy_id, in: :path, type: :string, required: true
      parameter name: :tailoring_id, in: :path, type: :string, required: true,
                description: 'UUID or OS minor version number'

      response '200', 'Returns a Tailoring File' do
        let(:request_params) do
          {
            'policy_id' => policy_id,
            'tailoring_id' => item.id
          }
        end
        schema ref_schema('tailoring_file')

        after { |e| autogenerate_examples(e, 'Returns a Tailoring File') }

        run_test!
      end
    end
  end
end
