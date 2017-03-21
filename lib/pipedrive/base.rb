require 'httparty'
require 'ostruct'
require 'forwardable'

module Pipedrive

  # Globally set request headers
  HEADERS = {
    "User-Agent"    => "Ruby.Pipedrive.Api",
    "Accept"        => "application/json",
    "Content-Type"  => "application/x-www-form-urlencoded"
  }

  # Base class for setting HTTParty configurations globally
  class Base < OpenStruct

    include HTTParty

    base_uri 'https://api.pipedrive.com/v1'
    headers HEADERS
    format :json

    extend Forwardable
    def_delegators 'self.class', :delete, :get, :post, :put, :resource_path, :bad_response

    attr_reader :data

    # Create a new Pipedrive::Base object.
    #
    # Only used internally
    #
    # @param [Hash] attributes
    # @return [Pipedrive::Base]
    def initialize(attrs = {})
      if attrs['data']
        struct_attrs = attrs['data']

        if attrs['additional_data']
          struct_attrs.merge!(attrs['additional_data'])
        end
        if attrs['related_objects']
          struct_attrs['related_objects'] = attrs['related_objects']
        end
      else
        struct_attrs = attrs
      end

      super(struct_attrs)
    end

    # Updates the object.
    #
    # @param [Hash] opts
    # @return [Boolean]
    def update(opts = {}, api_token = nil)
      original_path = "#{resource_path}/#{id}"
      path = api_token ? "#{original_path}?api_token=#{api_token}" : original_path
      res = put path, :body => opts
      if res.success?
        res['data'] = Hash[res['data'].map {|k, v| [k.to_sym, v] }]
        @table.merge!(res['data'])
      else
        false
      end
    end

    class << self
      # Sets the authentication credentials in a class variable.
      #
      # @param [String] email cl.ly email
      # @param [String] password cl.ly password
      # @return [Hash] authentication credentials
      def authenticate(token)
        default_params :api_token => token
      end

      # Examines a bad response and raises an appropriate exception
      #
      # @param [HTTParty::Response] response
      def bad_response(response, params={})
        if response.class == HTTParty::Response
          raise HTTParty::ResponseError, response
        end
        raise StandardError, 'Unknown error'
      end

      def new_list( attrs )
        attrs['data'].is_a?(Array) ? attrs['data'].map {|data| self.new( 'data' => data ) } : []
      end

      def all(api_token = nil, get_absolutely_all = true, response = nil, options={})
        path = api_token ? "#{resource_path}?api_token=#{api_token}" : resource_path
        res = get(path, options)
        if res.ok?
          data = res['data'].nil? ? [] : res['data'].map{|obj| new(obj)}
          if get_absolutely_all && has_pagination?(res)
            options[:query] = options[:query].merge({:start => res['additional_data']['pagination']['next_start']})
            data += self.all(nil,options, api_token, true)
          end
          data
        else
          bad_response(res,options)
        end
      end

      def has_pagination?(res)
        res['additional_data'] && res['additional_data']['pagination'] && res['additional_data']['pagination']['more_items_in_collection']
      end

      def create(opts = {}, api_token = nil)
        path = api_token ? "#{resource_path}?api_token=#{api_token}" : resource_path
        res = post path, :body => opts
        if res.success?
          res['data'] = opts.merge res['data']
          new(res)
        else
          bad_response(res,opts)
        end
      end

      def find(id, api_token = nil)
        res_path = "#{resource_path}/#{id}"
        path = api_token ? "#{res_path}?api_token=#{api_token}" : res_path
        res = get path
        res.ok? ? new(res) : bad_response(res,id)
      end

      def find_by_name(name, api_token = nil, opts={})
        opts.merge!({:api_token => api_token}) if api_token
        res = get "#{resource_path}/find", :query => { :term => name }.merge(opts)
        res.ok? ? new_list(res) : bad_response(res,{:name => name}.merge(opts))
      end

      def resource_path
        # The resource path should match the camelCased class name with the
        # first letter downcased.  Pipedrive API is sensitive to capitalisation
        klass = name.split('::').last
        klass[0] = klass[0].chr.downcase
        klass.end_with?('y') ? "/#{klass.chop}ies" : "/#{klass}s"
      end
    end
  end

end
