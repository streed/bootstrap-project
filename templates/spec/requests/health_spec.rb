require "rails_helper"

RSpec.describe "Health Check Endpoints", type: :request do
  describe "GET /health" do
    before { get health_path }

    it "returns HTTP 200" do
      expect(response).to have_http_status(:ok)
    end

    it "returns ok status in JSON" do
      json = response.parsed_body
      expect(json["status"]).to eq("ok")
    end

    it "includes a timestamp" do
      json = response.parsed_body
      expect(json["timestamp"]).to be_present
      expect { Time.iso8601(json["timestamp"]) }.not_to raise_error
    end

    it "includes rails and ruby versions" do
      json = response.parsed_body
      expect(json["rails"]).to eq(Rails.version)
      expect(json["ruby"]).to eq(RUBY_VERSION)
    end

    it "includes the application version" do
      json = response.parsed_body
      expect(json["version"]).to be_present
    end

    it "does not require authentication" do
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /health/db" do
    context "when the database is reachable" do
      before { get health_db_path }

      it "returns HTTP 200" do
        expect(response).to have_http_status(:ok)
      end

      it "returns ok status for postgresql" do
        json = response.parsed_body
        expect(json["status"]).to eq("ok")
        expect(json["service"]).to eq("postgresql")
      end
    end

    context "when the database is unreachable" do
      before do
        allow(ActiveRecord::Base.connection).to receive(:execute).and_raise(PG::ConnectionBad, "connection refused")
        get health_db_path
      end

      it "returns HTTP 503" do
        expect(response).to have_http_status(:service_unavailable)
      end

      it "returns error status with message" do
        json = response.parsed_body
        expect(json["status"]).to eq("error")
        expect(json["service"]).to eq("postgresql")
        expect(json["message"]).to be_present
      end
    end
  end

  describe "GET /health/redis" do
    context "when Redis is reachable" do
      before do
        redis_double = instance_double(Redis)
        allow(Redis).to receive(:new).and_return(redis_double)
        allow(redis_double).to receive(:ping).and_return("PONG")
        get health_redis_path
      end

      it "returns HTTP 200" do
        expect(response).to have_http_status(:ok)
      end

      it "returns ok status for redis" do
        json = response.parsed_body
        expect(json["status"]).to eq("ok")
        expect(json["service"]).to eq("redis")
      end
    end

    context "when Redis is unreachable" do
      before do
        allow(Redis).to receive(:new).and_raise(Redis::CannotConnectError, "connection refused")
        get health_redis_path
      end

      it "returns HTTP 503" do
        expect(response).to have_http_status(:service_unavailable)
      end

      it "returns error status with message" do
        json = response.parsed_body
        expect(json["status"]).to eq("error")
        expect(json["service"]).to eq("redis")
        expect(json["message"]).to be_present
      end
    end
  end
end
