# frozen_string_literal: true

module V2
  # Policies for accessing Reports
  class ReportPolicy < V2::ApplicationPolicy
    def index?
      true # FIXME: this is handled in scoping
    end

    def show?
      match_account?
    end

    def stats?
      match_account?
    end

    def destroy?
      match_account?
    end

    # :nocov:
    def os_versions?
      true
    end
    # :nocov:

    # Only show Reports in our user account
    class Scope < V2::ApplicationPolicy::Scope
      def resolve
        return scope.none if user&.account_id.blank?

        scope.where(account_id: user.account_id)
      end
    end
  end
end
