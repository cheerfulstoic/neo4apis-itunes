require './lib/author_parsing'
require 'neo4j-core'
require 'neo4j/core/cypher_session'

neo4j_session = Neo4j::Session.open(:server_db, 'http://neo4j:neo5j@localhost:9923')

neo4j_session.query.match('(e:Episode)').pluck('ID(e), e.title, e.description, e.itunes_author').each do |neo_id, title, description, itunes_author|
  puts
  puts "Parsing episode: #{title}"

  AuthorParsing.parse_author_string(itunes_author).each do |name|
    if name.split(/\s+/).size > 1
      neo4j_session.query('MERGE (p:Person {name: {name}}) WITH * MATCH (e:Episode) WHERE ID(e) = {episode_id} MERGE e-[:HAS_AUTHOR]->p', name: name, episode_id: neo_id)
      putc '+'
    else
      putc '-'
    end
  end

  AuthorParsing.parse_author_string(description).each do |name|
    if name.split(/\s+/).size > 1
      neo4j_session.query('MERGE (p:Person {name: {name}}) WITH * MATCH (e:Episode) WHERE ID(e) = {episode_id} MERGE e<-[:MENTIONED_IN]-p', name: name, episode_id: neo_id)
      putc '*'
    else
      putc '_'
    end
  end
end


