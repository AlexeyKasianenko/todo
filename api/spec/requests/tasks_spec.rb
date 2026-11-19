require "rails_helper"

RSpec.describe "Tasks", type: :request do
  let(:user) { User.create!(email_address: "owner@example.com", password: "password1") }
  let(:other_user) { User.create!(email_address: "other@example.com", password: "password1") }
  let(:token) { user.sessions.create!.signed_id }
  let(:headers) { { "Authorization" => "Bearer #{token}" } }

  def json
    response.parsed_body
  end

  describe "authentication" do
    it "returns 401 without a token" do
      get tasks_path, as: :json
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 401 with an invalid token" do
      get tasks_path, headers: { "Authorization" => "Bearer bogus" }, as: :json
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "GET /tasks" do
    let!(:older) { user.tasks.create!(title: "Older", status: :done, created_at: 1.day.ago) }
    let!(:newer) { user.tasks.create!(title: "Newer") }
    let!(:foreign) { other_user.tasks.create!(title: "Not mine") }

    it "lists only current user's tasks, newest first" do
      get tasks_path, headers: headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(json.map { |t| t["id"] }).to eq([ newer.id, older.id ])
    end

    it "filters by status" do
      get tasks_path(status: "done"), headers: headers, as: :json
      expect(json.map { |t| t["id"] }).to eq([ older.id ])
    end

    it "returns 422 for an unknown status" do
      get tasks_path(status: "archived"), headers: headers, as: :json
      expect(response).to have_http_status(:unprocessable_content)
      expect(json["errors"]).to have_key("status")
    end
  end

  describe "GET /tasks/:id" do
    let(:task) { user.tasks.create!(title: "Mine", note: "details") }

    it "returns the task" do
      get task_path(task), headers: headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(json).to include("id" => task.id, "title" => "Mine", "status" => "pending", "note" => "details")
      expect(json).not_to have_key("user_id")
    end

    it "returns 404 for another user's task" do
      foreign = other_user.tasks.create!(title: "Not mine")
      get task_path(foreign), headers: headers, as: :json
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /tasks" do
    it "creates a task for the current user" do
      expect {
        post tasks_path, params: { task: { title: "New", note: "n", status: "in_progress" } }, headers: headers, as: :json
      }.to change(user.tasks, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(json).to include("title" => "New", "status" => "in_progress", "note" => "n")
    end

    it "ignores user_id in params" do
      post tasks_path, params: { task: { title: "New", user_id: other_user.id } }, headers: headers, as: :json
      expect(Task.find(json["id"]).user).to eq(user)
    end

    it "returns 422 when title is missing" do
      post tasks_path, params: { task: { title: "" } }, headers: headers, as: :json
      expect(response).to have_http_status(:unprocessable_content)
      expect(json["errors"]).to have_key("title")
    end

    it "returns 422 for an unknown status" do
      post tasks_path, params: { task: { title: "X", status: "archived" } }, headers: headers, as: :json
      expect(response).to have_http_status(:unprocessable_content)
      expect(json["errors"]).to have_key("status")
    end
  end

  describe "PATCH /tasks/:id" do
    let(:task) { user.tasks.create!(title: "Old") }

    it "updates the task" do
      patch task_path(task), params: { task: { title: "New", status: "done" } }, headers: headers, as: :json

      expect(response).to have_http_status(:ok)
      expect(task.reload).to have_attributes(title: "New", status: "done")
    end

    it "returns 422 on invalid data" do
      patch task_path(task), params: { task: { title: "" } }, headers: headers, as: :json
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "returns 404 for another user's task" do
      foreign = other_user.tasks.create!(title: "Not mine")
      patch task_path(foreign), params: { task: { title: "Hacked" } }, headers: headers, as: :json
      expect(response).to have_http_status(:not_found)
      expect(foreign.reload.title).to eq("Not mine")
    end
  end

  describe "DELETE /tasks/:id" do
    it "deletes the task" do
      task = user.tasks.create!(title: "Bye")
      expect { delete task_path(task), headers: headers, as: :json }.to change(Task, :count).by(-1)
      expect(response).to have_http_status(:no_content)
    end

    it "returns 404 for another user's task" do
      foreign = other_user.tasks.create!(title: "Not mine")
      expect { delete task_path(foreign), headers: headers, as: :json }.not_to change(Task, :count)
      expect(response).to have_http_status(:not_found)
    end
  end
end
