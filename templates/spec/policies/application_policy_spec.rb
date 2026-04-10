require "rails_helper"

RSpec.describe ApplicationPolicy, type: :policy do
  subject { described_class.new(user, record) }

  let(:record) { double("Record", user_id: record_owner_id) }
  let(:record_owner_id) { nil }

  context "when user is nil (guest)" do
    let(:user) { nil }

    it { is_expected.to permit_action(:index) }
    it { is_expected.to permit_action(:show) }
    it { is_expected.to forbid_action(:create) }
    it { is_expected.to forbid_action(:new) }
    it { is_expected.to forbid_action(:update) }
    it { is_expected.to forbid_action(:edit) }
    it { is_expected.to forbid_action(:destroy) }
  end

  context "when user is a regular user" do
    let(:user) { create(:user) }

    it { is_expected.to permit_action(:index) }
    it { is_expected.to permit_action(:show) }
    it { is_expected.to permit_action(:create) }
    it { is_expected.to permit_action(:new) }
    it { is_expected.to forbid_action(:destroy) }

    context "when user owns the record" do
      let(:record_owner_id) { user.id }

      it { is_expected.to permit_action(:update) }
      it { is_expected.to permit_action(:edit) }
    end

    context "when user does not own the record" do
      let(:record_owner_id) { user.id + 999 }

      it { is_expected.to forbid_action(:update) }
      it { is_expected.to forbid_action(:edit) }
    end
  end

  context "when user is an admin" do
    let(:user) { create(:user, :admin) }

    it { is_expected.to permit_action(:index) }
    it { is_expected.to permit_action(:show) }
    it { is_expected.to permit_action(:create) }
    it { is_expected.to permit_action(:new) }
    it { is_expected.to permit_action(:update) }
    it { is_expected.to permit_action(:edit) }
    it { is_expected.to permit_action(:destroy) }
  end

  describe ApplicationPolicy::Scope do
    let(:scope) { double("Scope") }

    context "when user is an admin" do
      let(:user) { create(:user, :admin) }

      it "resolves to all records" do
        expect(scope).to receive(:all)
        described_class.new(user, scope).resolve
      end
    end

    context "when user is a regular user" do
      let(:user) { create(:user) }

      it "resolves to no records" do
        expect(scope).to receive(:none)
        described_class.new(user, scope).resolve
      end
    end

    context "when user is nil" do
      let(:user) { nil }

      it "resolves to no records" do
        expect(scope).to receive(:none)
        described_class.new(user, scope).resolve
      end
    end
  end
end
