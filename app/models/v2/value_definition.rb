# frozen_string_literal: true

module V2
  # Stores information about Value Definitions. This (eventually) comes from SCAP.
  class ValueDefinition < ApplicationRecord
    # FIXME: clean up after the remodel
    self.primary_key = :id
    self.table_name = :v2_value_definitions

    belongs_to :security_guide

    sortable_by :title

    searchable_by :title, %i[like unlike eq ne in notin]
  end
end
