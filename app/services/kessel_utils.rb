# frozen_string_literal: true

require 'kessel-sdk'

# Utilities used by Kessel
class KesselUtils
  class << self
    include Kessel::RBAC::V2
    include Kessel::Auth

    def get_default_workspace_id(auth, identity_header)
      parsed_identity = Insights::Api::Common::IdentityHeader.new(identity_header)
      cache_key = "workspace_default_#{parsed_identity.org_id}"

      cached_workspace_id = cached_workspace_id(cache_key)
      return cached_workspace_id if cached_workspace_id

      workspace_id = fetch_workspace_id(auth, parsed_identity.org_id)
      cache_workspace_id(cache_key, workspace_id)
      workspace_id
    end

    private

    def cached_workspace_id(cache_key)
      return unless @workspace_cache&.key?(cache_key)

      MemoryDiagnostics.event('kessel_workspace_cache', hit: true, size: @workspace_cache.size)
      @workspace_cache[cache_key]
    end

    def fetch_workspace_id(auth, org_id)
      fetch_default_workspace(
        Settings.endpoints.rbac.url,
        org_id,
        auth: oauth2_auth_request(auth),
        http_client: nil
      ).id
    end

    def cache_workspace_id(cache_key, workspace_id)
      @workspace_cache ||= {}
      @workspace_cache[cache_key] = workspace_id
      MemoryDiagnostics.event('kessel_workspace_cache', hit: false, size: @workspace_cache.size)
    end
  end
end
