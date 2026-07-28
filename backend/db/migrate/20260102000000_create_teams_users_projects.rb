# frozen_string_literal: true

class CreateTeamsUsersProjects < ActiveRecord::Migration[7.1]
  def change
    create_table :teams do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.text :settings
      t.timestamps
    end
    add_index :teams, :slug, unique: true

    create_table :users do |t|
      t.references :team, null: false, foreign_key: true
      t.string :email, null: false
      t.string :role, null: false, default: 'viewer'
      t.timestamps
    end
    add_index :users, :email, unique: true

    create_table :projects do |t|
      t.references :team, null: false, foreign_key: true
      t.string :name, null: false
      t.string :slug, null: false
      t.timestamps
    end
    add_index :projects, %i[team_id slug], unique: true
  end
end
