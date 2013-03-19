require 'sinatra/base'
require 'erb' # use Erb templates
require 'httparty'
require 'nokogiri'
require 'mongoid'
require 'mongoid_token'
require 'mongoid-pagination'

Mongoid.load!('./mongoid.yml', (ENV['RACK_ENV'] || 'development'))

class Takeover
  include Mongoid::Document
  include Mongoid::Timestamps
  include Mongoid::Token
  include Mongoid::Pagination

  field :html, type: String
  field :url,  type: String

  token length: 4
end

class App < Sinatra::Base

  configure :development do
    require 'ruby-debug'
  end

  helpers do
    def h(text)
      Rack::Utils.escape_html(text)
    end
  end

  get '/' do
    erb :index
  end

  get '/takeovers' do
    @takeovers = Takeover.paginate(page: params[:page])
    erb :takeovers
  end

  get '/:token' do
    takeover = Takeover.find_by_token params[:token]
    takeover ? takeover.html : (redirect '/')
  end

  post '/' do
    response = HTTParty.get params[:url]
    doc      = Nokogiri::HTML response.body
    head     = (doc.css 'head').first
    ele      = (doc.css params[:selector]).first

    head.add_child(%Q{
      <script
        src="https://d39v39m55yawr.cloudfront.net/assets/clr.js"
        type="text/javascript"
      ></script>
    }.strip.gsub(/\s+/m, ' '))

    if ele
      ele.add_next_sibling "<div>#{params[:urtak]}</div>"
    end

    takeover = Takeover.create html: doc.to_html, url: params[:url]
    redirect "/#{takeover.token}"
  end
end
