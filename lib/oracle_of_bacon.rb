# require 'debugger'              # optional, may be helpful
require 'open-uri'              # allows open('http://...') to return body
require 'cgi'                   # for escaping URIs
require 'nokogiri'              # XML parser
require 'active_model'          # for validations

class OracleOfBacon

  class InvalidError < RuntimeError ; end
  class NetworkError < RuntimeError ; end
  class InvalidKeyError < RuntimeError ; end

  attr_accessor :from, :to
  attr_reader :api_key, :response, :uri
  
  include ActiveModel::Validations
  validates_presence_of :from
  validates_presence_of :to
  validates_presence_of :api_key
  validate :from_does_not_equal_to

  def from_does_not_equal_to
    if @from.eql?(@to)
      errors.add(:from, 'From cannot be the same as To')
      errors.add(:to, 'From cannot be the same as To')
    end
  end

  def initialize(api_key='')
    @api_key = api_key
    @from = 'Kevin Bacon'
    @to = @from
  end

  def find_connections
    make_uri_from_arguments
    begin
      xml = URI.parse(uri).read
    rescue Timeout::Error, Errno::EINVAL, Errno::ECONNRESET, EOFError,
      Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError,
      Net::ProtocolError => e
      # convert all of these into a generic OracleOfBacon::NetworkError,
      #  but keep the original error message
      raise OracleOfBacon::NetworkError.new(e.message)
    end
    OracleOfBacon::Response.new(xml)
  end

  def make_uri_from_arguments
    # your code here: set the @uri attribute to properly-escaped URI
    #   constructed from the @from, @to, @api_key arguments
    @uri = "http://oracleofbacon.org/cgi-bin/xml?p=#{CGI.escape(@api_key)}&a=#{CGI.escape(@from)}&b=#{CGI.escape(@to)}"
    @uri
  end
      
  class Response
    attr_reader :type, :data
    # create a Response object from a string of XML markup.
    def initialize(xml)
      @doc = Nokogiri::XML(xml)
      parse_response
    end

    private

    def parse_response
      if parse_error_response
      # your code here: 'elsif' clauses to handle other responses
      # for responses not matching the 3 basic types, the Response
      # object should have type 'unknown' and data 'unknown response'
      elsif parse_graph_response
      elsif parse_spellcheck_response
      else
        parse_invalid_response
      end
    end
    def parse_invalid_response
      @type = :unknown
      @data = 'unknown response type'
    end
    def parse_error_response
      parse_collection_response(:error,'/error','Unauthorized access')
    end
    def parse_graph_response
      parse_collection_response(:graph,
                                '/link',
                                lambda{|collection|
                                        @data = []
                                        actors = collection.xpath('//actor').map(&:text)
                                        movies = collection.xpath('//movie').map(&:text)
                                        @data = actors.zip(movies).flatten.compact
                                      })
    end
    def parse_spellcheck_response
      parse_collection_response(:spellcheck,
                                '/spellcheck',
                                lambda{|collection|
                                        @data = collection.xpath('//match').map(&:text).flatten.compact
                                      })
    end
    def parse_collection_response(type=:error, xpath='/error',error='Unauthorized access')
      collection = @doc.xpath(xpath)
      if collection.empty?
        false
      else
        @type = type
        if error.is_a?(Proc)
          error.call(collection.children)
        else
          @data = error
        end
        true
      end
    end
  end
end

