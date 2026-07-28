# frozen_string_literal: true

class Project < ApplicationRecord
  belongs_to :team

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: { scope: :team_id }
end
