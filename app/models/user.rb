# frozen_string_literal: true

# Represents an individual Insights-Compliance user
class User < ApplicationRecord
  validates :username, uniqueness: { scope: :account_id }, presence: true
  validates_associated :account

  belongs_to :account

  delegate :account_number, to: :account

  def authorized_to?(access_request)
    return true if ActiveModel::Type::Boolean.new.cast(Settings.disable_rbac)

    puts " - '#{access_request}' request accepted by"
    n = rbac_permissions.any? do |access|
      a = Rbac.verify(access.permission, access_request)
      puts "=> '#{access.permission}'? #{a ? "✅" : "❌"}"
      a
    end
    puts "-" * 60
    n
  end

  private

  def rbac_permissions
    @rbac_permissions ||= Rbac.load_user_permissions(account.identity_header.raw)
  end

  class << self
    def current
      Thread.current[:user]
    end

    def current=(user)
      Thread.current[:user] = user
    end
  end
end
