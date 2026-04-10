require "rails_helper"

RSpec.describe "Sidekiq Web UI", type: :request do
  describe "GET /sidekiq" do
    context "when not authenticated" do
      it "redirects to sign in" do
        get "/sidekiq"
        expect(response).to have_http_status(:redirect)
      end
    end

    context "when authenticated as a regular user" do
      let(:user) { create(:user, admin: false) }

      before { sign_in user }

      it "does not allow access" do
        get "/sidekiq"
        expect(response).to have_http_status(:redirect)
      end
    end

    context "when authenticated as an admin" do
      let(:admin) { create(:user, :admin) }

      before { sign_in admin }

      it "allows access" do
        get "/sidekiq"
        expect(response).to have_http_status(:ok)
      end
    end
  end
end
