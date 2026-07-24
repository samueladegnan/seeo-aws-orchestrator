# frozen_string_literal: true

require "rails_helper"

RSpec.describe Environment, type: :model do
  let(:valid_attributes) do
    {
      id: "demo-123",
      project_name: "my-api",
      status: "ready",
      created_at: Time.current,
      expires_at: 1.hour.from_now,
      ttl_minutes: 60
    }
  end

  it "is valid with required attributes" do
    expect(Environment.new(valid_attributes)).to be_valid
  end

  it "is invalid without required attributes" do
    expect(Environment.new).not_to be_valid
  end

  it "is invalid with unsupported status" do
    env = Environment.new(valid_attributes.merge(status: "unknown"))
    expect(env).not_to be_valid
  end

  describe "#expired?" do
    it "returns true when expires_at is in the past" do
      env = Environment.new(valid_attributes.merge(expires_at: 1.minute.ago))
      expect(env.expired?).to be true
    end

    it "returns false when expires_at is in the future" do
      env = Environment.new(valid_attributes)
      expect(env.expired?).to be false
    end
  end

  describe "#to_h" do
    it "returns a hash representation" do
      env = Environment.new(valid_attributes)
      expect(env.to_h[:project_name]).to eq("my-api")
      expect(env.to_h[:status]).to eq("ready")
    end
  end
end
