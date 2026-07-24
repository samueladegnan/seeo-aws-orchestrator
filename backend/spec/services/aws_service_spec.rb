# frozen_string_literal: true

require "rails_helper"

RSpec.describe AwsService do
  let(:service) { described_class.new }

  before do
    allow(Aws::EC2::Client).to receive(:new).and_return(ec2_client)
    allow(Aws::DynamoDB::Client).to receive(:new).and_return(dynamodb_client)
  end

  let(:ec2_client) { instance_double(Aws::EC2::Client) }
  let(:dynamodb_client) { instance_double(Aws::DynamoDB::Client) }

  describe "#get_environment" do
    it "returns an environment when found" do
      allow(dynamodb_client).to receive(:get_item).and_return(
        Aws::DynamoDB::Types::GetItemOutput.new(
          item: {
            "id" => "demo-123",
            "project_name" => "my-api",
            "status" => "ready",
            "created_at" => Time.current.iso8601,
            "expires_at" => 1.hour.from_now.iso8601,
            "ttl_minutes" => 60
          }
        )
      )

      env = service.get_environment("demo-123")
      expect(env).to be_a(Environment)
      expect(env.project_name).to eq("my-api")
    end

    it "returns nil when not found" do
      allow(dynamodb_client).to receive(:get_item).and_return(
        Aws::DynamoDB::Types::GetItemOutput.new(item: nil)
      )

      expect(service.get_environment("missing")).to be_nil
    end
  end

  describe "#list_environments" do
    it "returns a list of environments" do
      allow(dynamodb_client).to receive(:scan).and_return(
        Aws::DynamoDB::Types::ScanOutput.new(items: [])
      )

      expect(service.list_environments).to eq([])
    end
  end
end
