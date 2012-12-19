class CollisionDomain < ActiveRecord::Base
  belongs_to :workspace
  has_many :interfaces
end
