# frozen_string_literal: true

require "rails_helper"

RSpec.describe AuthService do
  describe ".verify_api_key" do
    it "returns true for the configured key" do
      expect(AuthService.verify_api_key(SeeoConfig.api_key)).to be true
    end

    it "returns false for an invalid key" do
      expect(AuthService.verify_api_key("wrong-key")).to be false
    end

    it "returns false for nil" do
      expect(AuthService.verify_api_key(nil)).to be false
    end

    it "returns false for blank" do
      expect(AuthService.verify_api_key("   ")).to be false
    end
  end
end
