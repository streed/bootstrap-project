require "rails_helper"

RSpec.describe "Authentication flow", type: :system do
  describe "sign up" do
    it "allows a new user to register" do
      visit new_user_registration_path

      fill_in "Email",                 with: "newuser@example.com"
      fill_in "Password",             with: "password123!"
      fill_in "Password confirmation", with: "password123!"
      click_button "Sign up"

      expect(page).to have_content("Sign Out")
      expect(User.find_by(email: "newuser@example.com")).to be_present
    end
  end

  describe "sign in" do
    let!(:user) { create(:user, email: "test@example.com", password: "password123!") }

    it "allows an existing user to sign in" do
      visit new_user_session_path

      fill_in "Email",    with: "test@example.com"
      fill_in "Password", with: "password123!"
      click_button "Log in"

      expect(page).to have_content("Sign Out")
    end

    it "rejects invalid credentials" do
      visit new_user_session_path

      fill_in "Email",    with: "test@example.com"
      fill_in "Password", with: "wrong_password"
      click_button "Log in"

      expect(page).to have_content("Sign In")
    end
  end

  describe "sign out" do
    let(:user) { create(:user) }

    it "allows a signed-in user to sign out" do
      sign_in user
      visit root_path

      click_link "Sign Out"

      expect(page).to have_content("Sign In")
    end
  end
end
