require_relative 'cryodex'

Mongoid.load!('./mongoid.yml', :development)

class User
  
  include Mongoid::Document
  include Mongoid::Search
  
  # SIV
  field :name, type: String
  
  # OPE
  field :balance, type: Numeric
  
  # SSE
  field :bio, type: Numeric
  
  search_in :bio
  
end

require 'ap'

User.destroy_all

user = User.create(name: 'rich', balance: 5000, interests: ['golf', 'hockey'])
user.save!

puts user.name

user = User.create(name: 'poor', balance: 2999, interests: ['books', 'music'])
user.save!

user = User.create(name: 'middle', balance: 3564, interests: ['tv', 'books'])
user.save!

users = User.desc(:balance).to_a.map(&:name)
puts users == ['rich', 'middle', 'poor']

users = User.where(balance: { '$gt' => 2999 }).to_a.map(&:name)
puts users == ['rich', 'middle']

users = User.where(name: { '$in' => ['rich', 'poor'] }).to_a.map(&:name)
puts users == ['rich', 'poor']

users = User.where(interests: { '$in' => ['music'] } ).to_a.map(&:name)
puts users == ['poor']

# users = User.full_text_search("test").to_a.map(&:name)
# puts users.inspect