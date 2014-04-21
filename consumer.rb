require 'mongo'

client = Mongo::MongoClient.from_uri(ENV['CRYODEX_URL'])
db_name = ENV['CRYODEX_URL'].split('/').last

db = client[db_name]

coll   = db['example-collection']

10.times { |i| coll.insert({ count: i + 1 }) }