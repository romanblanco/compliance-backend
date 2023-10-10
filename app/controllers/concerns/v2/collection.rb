# frozen_string_literal: true

module V2
  # Generic methods to be used when calling resolve_collection on our models
  module Collection
    extend ActiveSupport::Concern

    include ::TagFiltering

    included do
      private

      def resolve_collection
        result = filter_by_tags(sort(search(policy_scope(expand_resource))))
        result.limit(pagination_limit).offset(pagination_offset)
      end

      # :nocov:
      def filter_by_tags(data)
        unless TagFiltering.tags_supported?(resource) && permitted_params[:tags]&.any?
          return data
        end

        tags = parse_tags(permitted_params[:tags])
        data.where('tags @> ?', tags.to_json)
      end
      # :nocov:

      # rubocop:disable Metrics/AbcSize
      # :nocov:
      def search(data)
        return data if permitted_params[self.class::SEARCH].blank?

        # Fail if search is not supported for the given model
        if !data.respond_to?(:search_for) || permitted_params[self.class::SEARCH].match(/\x00/)
          raise ActionController::UnpermittedParameters.new(self.class::SEARCH => permitted_params[self.class::SEARCH])
        end

        data.search_for(permitted_params[self.class::SEARCH])
      end
      # :nocov:
      # rubocop:enable Metrics/AbcSize

      # :nocov:
      def sort(data)
        order_hash, extra_scopes = data.klass.build_order_by(permitted_params[:sort_by])

        extra_scopes.inject(data.order(order_hash)) do |result, scope|
          result.send(scope)
        end
      end
      # :nocov:
    end
  end
end