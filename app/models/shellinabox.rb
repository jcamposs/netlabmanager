class Shellinabox < ActiveRecord::Base
  belongs_to :virtual_machine
  belongs_to :user
end
