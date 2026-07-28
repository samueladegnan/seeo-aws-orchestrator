# frozen_string_literal: true

# Default development data for SEEO

if Rails.env.development?
  team = Team.find_or_create_by!(slug: 'default') do |t|
    t.name = 'Default Team'
  end

  project = Project.find_or_create_by!(team: team, slug: 'demo') do |p|
    p.name = 'Demo Project'
  end

  User.find_or_create_by!(email: 'admin@seeo.local') do |u|
    u.team = team
    u.role = 'admin'
  end

  Rails.logger.debug { "Seeded default team '#{team.name}', project '#{project.name}', and admin user." }
end
