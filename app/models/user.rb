class User < ActiveRecord::Base
  has_many :scenes, dependent: :destroy
  has_many :workspaces
  has_many :shellinaboxes
  has_many :netlabsessions, dependent: :destroy

  validates :first_name, :last_name, presence: true
end
