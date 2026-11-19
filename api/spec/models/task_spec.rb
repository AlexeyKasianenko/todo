require "rails_helper"

RSpec.describe Task, type: :model do
  let(:user) { User.create!(email_address: "owner@example.com", password: "password1") }

  subject(:task) { described_class.new(title: "Buy milk", user: user) }

  it "is valid with title and user" do
    expect(task).to be_valid
  end

  it "defaults status to pending" do
    expect(task.status).to eq("pending")
  end

  it "requires a title" do
    task.title = ""
    expect(task).not_to be_valid
    expect(task.errors).to have_key(:title)
  end

  it "requires a user" do
    task.user = nil
    expect(task).not_to be_valid
    expect(task.errors).to have_key(:user)
  end

  it "rejects unknown status" do
    task.status = "archived"
    expect(task).not_to be_valid
    expect(task.errors).to have_key(:status)
  end

  it "accepts all defined statuses" do
    %w[pending in_progress done].each do |status|
      task.status = status
      expect(task).to be_valid
    end
  end

  it "is destroyed with its user" do
    task.save!
    expect { user.destroy }.to change(described_class, :count).by(-1)
  end
end
