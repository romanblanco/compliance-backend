# frozen_string_literal: true

module V2
  # Model for the SupportedProfiles view
  class SupportedProfile < ApplicationRecord
    # FIXME: clean up after the remodel
    self.table_name = :supported_profiles
    self.primary_key = :id

    searchable_by :os_major_version, %i[eq ne]
    searchable_by :title, %i[eq like]
    searchable_by :ref_id, %i[eq]

    sortable_by :title
    sortable_by :os_major_version
    sortable_by :os_minor_versions

    # Class method to get supported profiles with appropriate minor version handling
    def self.for_os_mode
      if consider_os_minor_versions?
        # Enterprise mode: return all profiles with their specific minor versions
        all
      else
        # Upstream mode: Use ActiveRecord to aggregate all minor versions per major version
        upstream_profiles
      end
    end

    # In upstream mode, return all possible minor versions for the major version
    def effective_os_minor_versions
      if consider_os_minor_versions?
        os_minor_versions
      else
        # Return all known minor versions for this major version from SupportedSsg
        SupportedSsg.by_os_major[os_major_version.to_s]&.map(&:os_minor_version)&.uniq&.sort || []
      end
    end

    private

    def self.consider_os_minor_versions?
      # Default to true to maintain backward compatibility
      Settings.consider_os_minor_versions != false
    end

    def consider_os_minor_versions?
      self.class.consider_os_minor_versions?
    end

    # ActiveRecord query for upstream mode using Arel
    def self.upstream_profiles
      profiles = Profile.arel_table
      security_guides = V2::SecurityGuide.arel_table
      os_minor_versions = V2::ProfileOsMinorVersion.arel_table

      query = Profile
        .joins(:security_guide)
        .joins(:os_minor_versions)
        .select(
          profiles[:ref_id],
          security_guides[:os_major_version],
          profiles[:id].maximum.as('id'),
          profiles[:title].maximum.as('title'),
          profiles[:description].maximum.as('description'),
          security_guides[:id].maximum.as('security_guide_id'),
          security_guides[:version].maximum.as('security_guide_version'),
          Arel::Nodes::NamedFunction.new(
            'ARRAY_AGG',
            [Arel::Nodes::Distinct.new(os_minor_versions[:os_minor_version])]
          ).as('os_minor_versions')
        )
        .group(profiles[:ref_id], security_guides[:os_major_version])
        .order(version_to_array(security_guides[:version].maximum).desc)

      query.map do |row|
        new(
          id: row.id,
          ref_id: row.ref_id,
          title: row.title,
          description: row.description,
          security_guide_id: row.security_guide_id,
          security_guide_version: row.security_guide_version,
          os_major_version: row.os_major_version,
          os_minor_versions: row.os_minor_versions
        )
      end
    end
  end
end
