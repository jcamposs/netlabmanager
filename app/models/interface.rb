class Interface < ActiveRecord::Base
  belongs_to :virtual_machine
  belongs_to :collision_domain
end
