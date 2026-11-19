class Task < ApplicationRecord
  belongs_to :user

  enum :status, { pending: 0, in_progress: 1, done: 2 }, default: :pending, validate: true

  validates :title, presence: true, length: { maximum: 255 }
end
