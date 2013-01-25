require 'sinatra/base'
require 'erb' # use Erb templates
require 'httparty'
require 'nokogiri'

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

  get '/takeover' do
    response = HTTParty.get params[:url]
    doc      = Nokogiri::HTML response.body
    head     = (doc.css "head").first
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
    doc.to_html
  end
end
