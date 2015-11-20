require './lib/author_parsing'
require 'neo4j-core'
#require 'neo4j/core/cypher_session'
require 'parallel'
require 'htmlentities'
require 'nokogiri'
require 'people'

coder = HTMLEntities.new

neo4j_session = Neo4j::Session.open(:server_db, 'http://neo4j:neo5j@localhost:5566')

NAME_PARSER = People::NameParser.new(case_mode: 'proper')

def standardize_name(name)
  result = NAME_PARSER.parse(name)
  [result[:first], result[:middle], result[:middle2], result[:last], result[:suffix]].map(&:strip).reject(&:empty?).join(' ')
end

neo4j_session.query.match('(show:Show)-[:HAS_EPISODE]->(episode:Episode)').where('episode.processed_for_authors IS NULL').pluck('show.name, collect({neo_id: ID(episode), title: episode.title, description: episode.description, itunes_author: episode.itunes_author})').each do |show_title, episodes|

  puts
  puts "Show: #{show_title}"


  episode_authors = episodes.map {|e| e[:itunes_author] }
  authors = Parallel.map(episode_authors, in_threads: 1) do |authors|
    puts authors
    AuthorParsing.parse_author_string(authors).uniq
  end


  descriptions = episodes.map do |e|
    description = e[:title].to_s + ' ' + e[:description].to_s
    description = Nokogiri::HTML(coder.decode(description)).xpath("//text()").to_s
    description
  end

  mentionees = Parallel.map(descriptions, in_threads: 1) do |description|
    puts description
    AuthorParsing.parse_author_string(description).uniq
  end

  # Add content_encoding

  episodes.zip(authors).each do |episode, authors|
    authors.map(&method(:standardize_name)).select {|author| author.split(/\s+/).size > 1 }.each do |author|
      neo4j_session.query('MERGE (p:Person {name: {name}, lower_name: lower({name}))}) WITH * MATCH (e:Episode) WHERE ID(e) = {episode_id} MERGE e-[:HAS_AUTHOR]->p', name: author, episode_id: episode[:neo_id])
    end
  end

  episodes.zip(mentionees).each do |episode, mentionees|
    mentionees.map(&method(:standardize_name)).select {|author| author.split(/\s+/).size > 1 }.each do |mentionee|
      neo4j_session.query('MERGE (p:Person {name: {name}, lower_name: lower({name})}) WITH * MATCH (e:Episode) WHERE ID(e) = {episode_id} MERGE e<-[:MENTIONED_IN]-p', name: mentionee, episode_id: episode[:neo_id])
    end
  end

  episode_ids = episodes.map {|episode| episode[:neo_id] }
  neo4j_session.query('MATCH (episode:Episode) WHERE ID(episode) IN {episode_ids} SET episode.processed_for_authors = true', episode_ids: episode_ids)
end


