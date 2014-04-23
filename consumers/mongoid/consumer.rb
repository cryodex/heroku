SpecPersonas = [
  { name: 'rich', balance: 5000, interests: ['golf', 'hockey'], bio: 'I like stuff' },
  { name: 'poor', balance: 2999, interests: ['books', 'music'], bio: 'This is a test test' },
  { name: 'middle', balance: 3564, interests: ['tv', 'books'], bio: 'Hello to world!' }
]

require 'openssl'
require 'ruby-prof'

def random_nonce(n = 4)
  OpenSSL::Random.random_bytes(n)
end

def benchmark
  
  Benchmark.bm do |x|
    
    puts "1000 inserts (1)"
    x.report do 
      
      RubyProf.start
      
      500.times do
        
        user = User.create(SpecPersonas[0])
        user.save!
      end
      
      result = RubyProf.stop

      # Print a flat profile to text
      printer = RubyProf::FlatPrinter.new(result)
      printer.print(STDOUT)
      
    end
    
    puts "1000 inserts (2)"
    
    x.report do 
      500.times do
        user = User.create(SpecPersonas[1])
        user.save!
      end
    end
    
    puts "1000 inserts (3)"
    x.report do 
      500.times do
        user = User.create(SpecPersonas[2])
        user.save!
      end
    end
    
    puts "1000 sort queries"
    x.report do
      1000.times do
        users = User.desc(:balance) #.to_a.map(&:name)
        # puts users == ['rich', 'middle', 'poor']
      end
    end
    
    puts "1000 range queries"
    x.report do 
      1000.times do
        users = User.where(balance: { '$gt' => 2999 }, nonce: random_nonce ) #.to_a.map(&:name)
        #puts users == ['rich', 'middle']
      end
    end
    
    puts "1000 $in queries, 1 elem in array"
    x.report do   
      1000.times do
        users = User.where(interests: { '$in' => ['music'] }, nonce: random_nonce) #.to_a.map(&:name)
        # puts users == ['poor']
      end
    end
    
    puts "1000 $in queries, 2 elems in array"
    x.report do 
      1000.times do
        users = User.where(name: { '$in' => ['rich', 'poor'], nonce: random_nonce }) #.to_a.map(&:name)
        #puts users == ['rich', 'poor']
      end
    end
    
    
    puts "1000 fulltext search queries (with $in)"
    x.report do 
      1000.times do
        users = User.full_text_search("test") #.to_a.map(&:name)
        # puts users == ['poor']
      end
    end
    
  end
  
  puts '-------'
  
end

require 'mongoid'
require 'mongoid_search'

Mongoid.load!('./mongoid.yml', :development)

class User
  
  include Mongoid::Document
  include Mongoid::Search
  
  # SIV
  field :name, type: String
  
  # OPE
  field :balance, type: Numeric
  
  # SSE
  field :bio, type: String
  
  search_in :bio
  
end

require 'ap'

benchmark

User.destroy_all
require_relative 'cryodex'

benchmark

=begin
puts user.name

=end