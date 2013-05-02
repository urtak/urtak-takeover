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

  def initialize(url, urtak_code, selector, selector_type, ad_rotation)
    @url           = Addressable::URI.parse url
    @urtak_code    = urtak_code
    @selector      = selector
    @selector_type = selector_type
    @ad_rotation   = ['1', 'true', 'on'].include? ad_rotation.to_s

    # Let's party!
    response = HTTParty.get @url

    # Nokogirize!
    @doc = Nokogiri::HTML response.body
  end

  def fetch_clean_and_takeover!
    insert_urtak_script!
    make_links_absolute!
    hack_aol_ad_server!
    hack_pagespeed_lazy_src!
    if @ad_rotation
      insert_fugger_script!
    end
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
    head.add_child(%Q{
      <script
        src="https://d39v39m55yawr.cloudfront.net/assets/clr.js"
        type="text/javascript"
      ></script>
    }.strip.gsub(/\s+/m, ' '))
  end

  def ad_tags
    start = %Q{
      <div style="display:none;">
        <img src="/img/ad-rotation/1.png"/>
        <img src="/img/ad-rotation/2.png"/>
        <img src="/img/ad-rotation/3.png"/>
        <img src="/img/ad-rotation/4.png"/>
        <img src="/img/ad-rotation/5.png"/>
        <img src="/img/ad-rotation/6.png"/>
        <img src="/img/ad-rotation/7.png"/>
        <img src="/img/ad-rotation/8.png"/>
      </div>
      <script type="text/javascript">
        (function () {
          if (!window.__urtak_counter__) {
            window.__urtak_counter__ = 0;
          }
          r = window.Urtak2.$("[id^=urtak-rotation]");
          r.css("z-index", 100000);
          r.find("img").hide();
          r.find("img:eq(" + window.__urtak_counter__ + ")").show();
          r.find("div").show();
          window.__urtak_counter__ += 1;
          if (window.__urtak_counter__ === r.find("img").size()) {
            window.__urtak_counter__ = 0;
          }
        }());
    }.gsub('"', '\"').gsub("\n", '')
    %Q{
      "#{start}" + "</" + "script>"
    }.strip
  end

  def insert_fugger_script!
    head.add_child(%Q{
      <script
        src="https://d39v39m55yawr.cloudfront.net/assets/fugger.js"
        type="text/javascript"
      ></script>
      <script type="text/javascript">
        window.Urtak2.createRotation(#{ad_tags});
      </script>
    }.strip.gsub(/\s+/m, ' '))
  end

  def head
    @head ||= (@doc.css 'head').first
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

  def hack_aol_ad_server!
    s = (@doc.search 'script').detect { |node| node.content =~ /adSetAdURL/ }
    s.content = s.content.gsub(
      /adSetAdURL\("(.*?)"\)/,
      "adSetAdURL(\"#{@url_host}\\1\")"
    )
  end

  def hack_pagespeed_lazy_src!
    (@doc.css 'img[pagespeed_lazy_src]').each do |img|
      img['src'] = img['pagespeed_lazy_src']
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
    begin
      (Takeover.find_by_token params[:token]).html
    rescue Mongoid::Errors::DocumentNotFound
      pass
    end
  end

  post '/' do
    page_parser = PageParser.new params[:url],
      params[:urtak],
      params[:selector],
      params[:selector_type],
      params[:ad_rotation]

    page_parser.fetch_clean_and_takeover!

    takeover = Takeover.create html: page_parser.html, url: page_parser.url
    redirect "/#{takeover.token}"
  end
end
