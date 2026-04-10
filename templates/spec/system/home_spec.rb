require "rails_helper"

RSpec.describe "Home page", type: :system do
  it "displays the welcome message" do
    visit root_path
    expect(page).to have_content("Welcome")
  end

  it "shows sign-in and sign-up links to guests" do
    visit root_path
    expect(page).to have_link("Sign In")
    expect(page).to have_link("Sign Up")
  end

  context "when signed in" do
    let(:user) { create(:user) }

    before do
      sign_in user
      visit root_path
    end

    it "shows a sign-out link" do
      expect(page).to have_link("Sign Out")
    end

    it "does not show sign-in link" do
      expect(page).not_to have_link("Sign In")
    end
  end
end
