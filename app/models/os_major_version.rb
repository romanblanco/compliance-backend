# frozen_string_literal: true

# Pseudo-class for retrieving supported OS major versions
class OsMajorVersion < ApplicationRecord
  self.table_name = 'benchmarks'

  # Helper function that aggregates a column under a grouping and orders them
  # descending based on their benchmark version.
  def self.aggregated_cast(column)
    AN::NamedFunction.new(
      'array_agg',
      [AN::InfixOperation.new(
        'ORDER BY',
        column,
        AN::Descending.new(
          Xccdf::Benchmark::SORT_BY_VERSION
        )
      )]
    )
  end

  OS_MAJOR_VERSION = AN::NamedFunction.new(
    'CAST',
    [
      AN::NamedFunction.new(
        'REPLACE',
        [
          arel_table[:ref_id],
          AN::Quoted.new("#{Xccdf::Benchmark::REF_PREFIX}-"),
          AN::Quoted.new('')
        ]
      ).as('int')
    ]
  ).as('os_major_version')

  PROFILE_LAST_ID = Arel.sql("(#{aggregated_cast(Profile.arel_table[:id]).to_sql})[1] as \"id\"")
  PROFILE_BM_VERSIONS = aggregated_cast(arel_table[:version]).as('bm_versions')

  default_scope do
    select(OS_MAJOR_VERSION, :ref_id).distinct.order(:os_major_version)
  end

  has_many :benchmarks, class_name: 'Xccdf::Benchmark',
                        foreign_key: 'ref_id', primary_key: 'ref_id',
                        inverse_of: false, dependent: :restrict_with_exception

  has_many :profiles, lambda {
    supported_profiles = canonical.where(upstream: false)
                                  .joins(:benchmark)
                                  .select(PROFILE_LAST_ID, PROFILE_BM_VERSIONS, OS_MAJOR_VERSION)
                                  .group(:ref_id, 'os_major_version')

    canonical.where(upstream: false)
             .joins("INNER JOIN (#{supported_profiles.to_sql}) t ON t.id = profiles.id")
             .select('"profiles".*, "t"."bm_versions" AS "bm_versions", "t"."os_major_version" AS "os_major_version"')
  }, through: :benchmarks

  def readonly?
    true
  end

  def os_major_version
    attributes['os_major_version']
  end
end
