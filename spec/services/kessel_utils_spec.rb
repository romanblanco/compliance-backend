# frozen_string_literal: true

require 'rails_helper'

RSpec.describe KesselUtils, type: :service do
  let(:user) { create(:user) }
  let(:auth) { double('oauth_credentials') }
  let(:workspace) { double('workspace', id: "default-workspace-#{user.org_id}") }

  before do
    described_class.instance_variable_set(:@workspace_cache, nil)
    allow(described_class).to receive(:oauth2_auth_request).with(auth).and_return(auth)
    allow(described_class).to receive(:fetch_default_workspace).and_return(workspace)
  end

  it 'caches the default workspace per organization' do
    identity_header = user.account.identity_header.raw

    expect(described_class).to receive(:fetch_default_workspace).once.and_return(workspace)

    2.times { expect(described_class.get_default_workspace_id(auth, identity_header)).to eq(workspace.id) }
  end
end
