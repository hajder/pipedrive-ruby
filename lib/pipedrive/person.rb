module Pipedrive
  class Person < Base
    def self.filter(filter_id, fetch_all_pages = true)
      acc = []
      start = 0
      limit = 500
      loop do
        response = Person.get resource_path, query: { filter_id: filter_id, start: start, limit: limit, owned_by_you: 0 }
        acc.push(*Person.new_list(response))
        break unless response['additional_data']['pagination']['more_items_in_collection']
        break unless fetch_all_pages
        start += limit
      end
      acc
      
      return acc
    end

    class << self

      def find_or_create_by_name(name, opts={})
        find_by_name(name, :org_id => opts[:org_id]).first || create(opts.merge(:name => name))
      end

    end

    def deals()
      Deal.new_list(get "#{resource_path}/#{id}/deals", :everyone => 1)
    end
  end
end
