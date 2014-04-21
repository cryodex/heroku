require 'mongo'

begin
  
  client = Mongo::MongoClient.from_uri(ENV['CRYODEX_URL'])
  db = client[ENV['CRYODEX_URL'].split('/').last]

  coll = db['example-collection']

  10.times { |i| coll.insert({ count: i + 1 }) }
  
rescue => e
  
  abort "Failed to access database: #{e.message}"
  
end