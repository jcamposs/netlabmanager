class Scene < ActiveRecord::Base
  belongs_to :user
  has_many :workspaces, dependent: :destroy

  validates :name, presence: true
end
