require 'open-uri'
require 'json'
require 'active_support/core_ext/hash/keys'
require 'active_support/inflector'
require 'active_support/cache'
require 'simple-rss'

SimpleRSS.item_tags << 'itunes:author'

require 'neo4apis'
require 'neo4j/core/cypher_session' # Grr

require 'net/https'

module Net
  class HTTP
    alias_method :original_use_ssl=, :use_ssl=
    def use_ssl=(flag)
      self.ca_file = '/etc/openssl/cacert.pem'
      self.original_use_ssl = flag
    end
  end
end

CACHE = ActiveSupport::Cache::FileStore.new('cache')
def get_url_body(url)
  CACHE.fetch(url) do
    URI.parse(url).open.read
  end
end

module Neo4Apis
  class ITunes < Base
    # Adds a prefix to labels so that they become AwesomeSiteUser and AwesomeSiteWidget (optional)
    common_label :iTunes

    # Number of queries which are built up until batch request to DB is made (optional, default = 500)
    batch_size 2000

    uuid :Genre, :id
    uuid :Artist, :id
    uuid :Show, :id
    uuid :Episode, :guid

    importer :Show do |show_data|
      show_data = show_data.transform_keys(&:underscore)

      begin
        rss = SimpleRSS.parse get_url_body(show_data['feed_url'])

        episode_nodes = rss.items.map do |episode|
          keys = %w(guid title link description content content_encoded itunes_author)
          if episode.guid
            add_node(:Episode) do |n|
              keys.each do |key|
                value = episode.send(key)
                n.send("#{key}=", value.force_encoding('UTF-8')) unless value.nil?
              end
            end
          end
        end.compact

        genre_nodes = show_data['genre_ids'].zip(show_data['genres']).map do |id, name|
          add_node(:Genre) do |n|
            n.id = id.to_i
            n.name = name
          end
        end

        unless show_data['artist_id'].nil?
          artist_node = add_node(:Artist) do |n|
            n.id = show_data['artist_id']
            n.name = show_data['artist_name']
            n.view_url = show_data['artist_view_url']
          end
        end

        keys = %w(feed_url artwork_url30 artwork_url60 artwork_url100
                  release_date country primary_genre_name radio_station_url artwork_url600)
        node = add_node(:Show) do |n|
          keys.each do |key|
            n.send("#{key}=", show_data[key])
          end

          n.id = show_data['collection_id']
          n.name = show_data['collection_name']
          n.view_url = show_data['collection_view_url']
          n.explicitness = show_data['collection_explicitness']
          n.episode_count = show_data['track_count']
        end

        genre_nodes.each do |genre_node|
          add_relationship(:OF_GENRE, node, genre_node)
        end

        add_relationship(:FROM_ARTIST, node, artist_node) if artist_node

        episode_nodes.each do |episode_node|
          add_relationship(:HAS_EPISODE, node, episode_node)
        end

        node
        putc '+'
      rescue SimpleRSSError
        putc '-'
      end
    end

  end
end

neo4j_session = Neo4j::Session.open(:server_db, 'http://neo4j:neo5j@localhost:9923')
neo4apis_itunes = Neo4Apis::ITunes.new(neo4j_session)

terms = File.read('terms').split(/[\n\r]+/)

terms.each do |term|
  puts
  puts "Querying for term: #{term}"

  neo4apis_itunes.batch do
    url = "https://itunes.apple.com/search?media=podcast&term=#{term}&limit=200"

    data = JSON.parse(get_url_body(url))

    count = data['resultCount']
    results = data['results']

    results.each do |show_data|
      neo4apis_itunes.import :Show, show_data
    end
  end
end


