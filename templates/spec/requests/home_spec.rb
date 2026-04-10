require "rails_helper"

RSpec.describe "Home", type: :request do
  describe "GET / (root)" do
    context "when not authenticated" do
      before { get root_path }

      it "returns HTTP 200" do
        expect(response).to have_http_status(:ok)
      end

      it "renders the home page" do
        expect(response.body).to include("Welcome")
      end

      it "shows sign-in and sign-up links" do
        expect(response.body).to include("Sign In")
        expect(response.body).to include("Sign Up")
      end
    end

    context "when authenticated" do
      let(:user) { create(:user) }

      before do
        sign_in user
        get root_path
      end

      it "returns HTTP 200" do
        expect(response).to have_http_status(:ok)
      end

      it "shows sign-out link" do
        expect(response.body).to include("Sign Out")
      end
    end
  end
end
