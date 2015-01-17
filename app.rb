# encoding: utf-8
require 'sinatra/base'
# require 'sinatra/namespace'
require 'haml'
require 'json'

class MyApp < Sinatra::Base
	# register Sinatra::Namespace
	enable :sessions
  set :session_secret, ENV['secret']
  # disable :logging
  set :haml, format: :html5
  set :javascripts, [:main]
  set :stylesheets, [:main]

  configure :production do
    # require 'newrelic_rpm'
    # use Rack::SslEnforcer, :only => [%r{^/user/}, %r{^/log}, %r{^/signup}, %r{^/admin/}]
    set :haml, { :ugly=>true }
    set :clean_trace, false

  end

  configure :development do
		# set :public_folder,
	end


  helpers do
    include Rack::Utils
    alias_method :h, :escape_html

  end
end


require_relative 'helpers/init'
require_relative 'lib/init'
require_relative 'models/init'
require_relative 'routes/init'
MyApp.run! if __FILE__ == $0
