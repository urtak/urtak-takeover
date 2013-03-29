require 'sinatra/base'
require 'erb' # use Erb templates
require 'httparty'
require 'nokogiri'
require 'mongoid'
require 'mongoid_token'
require 'mongoid-pagination'
require 'addressable/uri'

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

class PageParser

  def initialize(url, urtak_code, selector, selector_type)
    @url           = Addressable::URI.parse url
    @urtak_code    = urtak_code
    @selector      = selector
    @selector_type = selector_type

    # Let's party!
    response = HTTParty.get @url

    # Nokogirize!
    @doc = Nokogiri::HTML response.body
  end

  def fetch_clean_and_takeover!
    insert_urtak_script!
    make_links_absolute!
    add_urtak!
  end

  def html
    @doc.to_html
  end

  attr_reader :url

  private

  def add_urtak!
    if @selector =~ /[^[:space:]]/
      ele = (@doc.css @selector).first
      if ele
        if @selector_type == 'append'
          ele.add_next_sibling "<div>#{@urtak_code}</div>"
        elsif @selector_type == 'replace'
          new_node = @doc.create_element 'div'
          new_node.inner_html = @urtak_code
          ele.replace new_node
        end
      end
    end
  end

  # Insert Urtak script into head.
  def insert_urtak_script!
    head = (@doc.css 'head').first
    head.add_child(%Q{
      <script
        src="https://d39v39m55yawr.cloudfront.net/assets/clr.js"
        type="text/javascript"
      ></script>
    }.strip.gsub(/\s+/m, ' '))
  end

  def make_links_absolute!
    (@doc.css '*[href]').each { |ele| process_ele_url!(ele, :href) }
    (@doc.css '*[src]').each { |ele| process_ele_url!(ele, :src) }
  end

  def process_ele_url!(ele, attribute)
    # If href does not start with "http" or "//"...
    unless full_url? ele[attribute]
      # For leading slashes we only need the domain. For relative urls we
      # need the path.
      if ele[attribute][0] == '/'
        ele[attribute] = "#{url_host}#{ele[attribute]}"
      else
        ele[attribute] = "#{url_with_path_and_slash}#{ele[attribute]}"
      end
    end
  end

  def full_url?(url)
    url =~ %r{^(https?:)?//} ? true : false
  end

  def url_host
    @url_host ||= "#{@url.scheme}://#{@url.host}"
  end

  def url_with_path_and_slash
    @url_with_path_and_slash ||=
      begin
        url = "#{url_host}#{@url.path}"
        url = "#{url}/" if url[-1] != '/'
        url
      end
  end
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
    page_parser = PageParser.new params[:url],
      params[:urtak],
      params[:selector],
      params[:selector_type]

    page_parser.fetch_clean_and_takeover!

    takeover = Takeover.create html: page_parser.html, url: page_parser.url
    redirect "/#{takeover.token}"
  end
end
