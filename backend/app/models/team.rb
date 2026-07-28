# frozen_string_literal: true

class Team < ApplicationRecord
  has_many :users, dependent: :destroy
  has_many :projects, dependent: :destroy

  validates :name, :slug, presence: true
  validates :slug, uniqueness: true

  serialize :settings, coder: JSON

  def settings
    super || {}
  end
end
