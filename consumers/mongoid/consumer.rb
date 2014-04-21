require_relative 'cryodex'

Mongoid.load!('./mongoid.yml', :development)

class User
  
  include Mongoid::Document
  
  # SIV
  field :name, type: String
  
  # SSE
  field :bio, type: String
  
  # Paillier + OPE
  field :age, type: Numeric
  
  # AES-CCM
  field :diary, type: String
  
  field :password, type: String
  
end

require 'ap'

User.destroy_all

user = User.create(name: 'louis', password: 'test123', bio: 'this is a secret message')
user.save!

puts user.name.inspect

user = User.where(name: 'louis').first
puts user.name