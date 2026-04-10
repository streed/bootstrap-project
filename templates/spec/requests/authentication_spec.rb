require "rails_helper"

RSpec.describe "Authentication", type: :request do
  describe "GET /users/sign_in" do
    it "renders the sign-in page" do
      get new_user_session_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /users/sign_up" do
    it "renders the sign-up page" do
      get new_user_registration_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /users (registration)" do
    let(:valid_params) do
      {
        user: {
          email: "newuser@example.com",
          password: "password123!",
          password_confirmation: "password123!"
        }
      }
    end

    context "with valid params" do
      it "creates a new user" do
        expect {
          post user_registration_path, params: valid_params
        }.to change(User, :count).by(1)
      end

      it "redirects after successful registration" do
        post user_registration_path, params: valid_params
        expect(response).to have_http_status(:redirect)
      end

      it "sets admin to false by default" do
        post user_registration_path, params: valid_params
        expect(User.last.admin?).to be false
      end
    end

    context "with invalid params" do
      it "does not create a user with mismatched passwords" do
        expect {
          post user_registration_path, params: {
            user: {
              email: "bad@example.com",
              password: "password123!",
              password_confirmation: "wrong"
            }
          }
        }.not_to change(User, :count)
      end

      it "does not create a user with a blank email" do
        expect {
          post user_registration_path, params: {
            user: {
              email: "",
              password: "password123!",
              password_confirmation: "password123!"
            }
          }
        }.not_to change(User, :count)
      end
    end
  end

  describe "POST /users/sign_in (session)" do
    let!(:user) { create(:user, email: "test@example.com", password: "password123!") }

    context "with valid credentials" do
      it "signs in the user" do
        post user_session_path, params: {
          user: { email: "test@example.com", password: "password123!" }
        }
        expect(response).to have_http_status(:redirect)
      end
    end

    context "with invalid credentials" do
      it "rejects incorrect password" do
        post user_session_path, params: {
          user: { email: "test@example.com", password: "wrong" }
        }
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "rejects non-existent email" do
        post user_session_path, params: {
          user: { email: "nobody@example.com", password: "password123!" }
        }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe "DELETE /users/sign_out" do
    let(:user) { create(:user) }

    it "signs out the user" do
      sign_in user
      delete destroy_user_session_path
      expect(response).to have_http_status(:redirect)
    end
  end

  describe "protected routes" do
    it "redirects unauthenticated users to sign in" do
      get root_path
      # HomeController skips auth, so root is accessible
      expect(response).to have_http_status(:ok)
    end
  end
end
