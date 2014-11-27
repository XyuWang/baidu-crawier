require 'rubygems'
require 'bundler/setup'

require 'active_record'
require 'mysql2'

def establish_conn
  ActiveRecord::Base.establish_connection(
  adapter:  'mysql2',
  host:     'localhost',
  username: 'root',
  password: 'password',
  database: 'baidu'
  )
end


class Name < ActiveRecord::Base
  has_many :links, dependent: :destroy
  scope :completed, -> {where completed: true}
  scope :uncompleted, -> {where completed: false}
  validates :name, uniqueness: true
end

class Link < ActiveRecord::Base
  belongs_to :name
  validates :name_id, :title, :href, presence: true 
end

I18n.enforce_available_locales = false
establish_conn
