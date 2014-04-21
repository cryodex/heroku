require 'bundler'
Bundler.require

STDOUT.sync = true

class App < Sinatra::Base
  
  require 'mongoid'
  require 'mongo'
  
  Mongoid.load!('./mongoid.yml', :development)
  
  class Tenant
    
    include Mongoid::Document
    
    field :heroku_id, type: String
    field :plan, type: String
    field :callback_url, type: String
    field :options, type: Hash
    
    field :username, type: String
    field :password, type: String
    field :databases, type: Array
    
  end
  
  AdminURI = 'mongodb://admin:123456@localhost:27017/admin'
  Host = 'localhost:27017'
  
  use Rack::Session::Cookie, secret: ENV['SSO_SALT']
  
  @@resources = []

  Resource = Class.new(OpenStruct)
  
  helpers do
    
    def protected!
      unless authorized?
        response['WWW-Authenticate'] = %(Basic realm="Restricted Area")
        throw(:halt, [401, "Not authorized\n"])
      end
    end

    def authorized?
      @auth ||=  Rack::Auth::Basic::Request.new(request.env)
      @auth.provided? && @auth.basic? && @auth.credentials &&
      @auth.credentials == [ENV['HEROKU_USERNAME'], ENV['HEROKU_PASSWORD']]
    end

    def show_request
      body = request.body.read
      unless body.empty?
        STDOUT.puts "request body:"
        STDOUT.puts(@json_body = JSON.parse(body))
      end
      unless params.empty?
        STDOUT.puts "params: #{params.inspect}"
      end
    end

    def json_body
      @json_body || (body = request.body.read && JSON.parse(body))
    end

    def get_resource
      Tenant.find(params[:id])
    rescue
      halt 404, 'resource not found'
    end
  end

  # sso landing page
  get "/" do
    halt 403, 'not logged in' unless session[:heroku_sso]
    #response.set_cookie('heroku-nav-data', value: session[:heroku_sso])
    @resource = session[:resource]
    @email    = session[:email]
    haml :index
  end

  def sso
    pre_token = params[:id] + ':' + ENV['SSO_SALT'] + ':' + params[:timestamp]
    token = Digest::SHA1.hexdigest(pre_token).to_s
    halt 403 if token != params[:token]
    halt 403 if params[:timestamp].to_i < (Time.now - 2*60).to_i

    halt 404 unless session[:resource]   = get_resource

    response.set_cookie('heroku-nav-data', value: params['nav-data'])
    session[:heroku_sso] = params['nav-data']
    session[:email]      = params[:email]

    redirect '/'
  end

  # sso sign in
  get "/heroku/resources/:id" do
    show_request
    sso
  end

  post '/sso/login' do
    puts params.inspect
    sso
  end
  
  # mongodb://535561fb2193e2edec000001:79922195890938c26d831e69676c6a11@localhost:27017/535561fb2193e2edec000001

  # provision
  post '/heroku/resources' do
    
    show_request
    protected!
    
    if json_body['region'] != 'amazon-web-services::us-east-1'
      status 422
      body({:error => 'Region is not supported by this provider.'}.to_json)
    end
    
    username = OpenSSL::Random.random_bytes(8).unpack("H*").first
    password = OpenSSL::Random.random_bytes(18).unpack("H*").first
    database = OpenSSL::Random.random_bytes(10).unpack("H*").first
    
    tenant = Tenant.new(:heroku_id => json_body['heroku_id'],
                        :plan => json_body.fetch('plan', 'test'),
                        :region => json_body['region'],
                        :callback_url => json_body['callback_url'],
                        :options => json_body['options'],
                        :username => username,
                        :password => password,
                        :databases => [database])
    
    client = Mongo::MongoClient.from_uri(AdminURI)
    
    db = client[database]
    db.add_user(username, password, false, { roles: ['dbAdmin', 'readWrite'] })
    
    uri = "mongodb://#{username}:#{password}@#{Host}/#{database}"
    
    status 201
    
    body({
      :id => tenant.id.to_s,
      :config => { "CRYODEX_URL" => uri },
      :message => 'Your addon is now provisioned!'
    }.to_json)
    
  end

  # deprovision
  delete '/heroku/resources/:id' do |id|
    show_request
    protected!
    
    client = Mongo::MongoClient.from_uri(AdminURI)
    client.drop_database(id)
    
    get_resource.destroy
    
    "ok"
  end

  # plan change
  put '/heroku/resources/:id' do
    show_request
    protected!
    resource = get_resource
    resource.plan = json_body['plan']
    resource.save!
    {}.to_json
  end
  
end
