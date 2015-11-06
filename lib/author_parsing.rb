require 'active_support/cache'

CACHE = ActiveSupport::Cache::FileStore.new('nlp_cache')
require 'json'

def get_nlp_result(text)
  CACHE.fetch(text) do
    File.open('input.txt', 'w') { |f| f << text }
    #command = 'java -cp "*" -Xmx2g edu.stanford.nlp.pipeline.StanfordCoreNLP -annotators tokenize,ssplit,pos,lemma,ner,parse,dcoref -file input.txt -outputFormat json'
    command = 'java -cp "*" -Xmx2g edu.stanford.nlp.pipeline.StanfordCoreNLP -annotators tokenize,ssplit,pos,lemma,ner -file input.txt -outputFormat json'
    system("#{command} 2> /dev/null")
    File.read('input.txt.json')
  end
rescue Errno::ENOENT
ensure
  `rm input.txt 2> /dev/null`
  `rm input.txt.json 2> /dev/null`
end


module AuthorParsing
  def self.parse_author_string(author_string)
    return [] if author_string.to_s.strip.empty?

    extra = []
    if author_string.match('CGP Grey')
      author_string.gsub!('CGP Grey', '')
      extra << 'CGP Grey'
    end

    nlp_result = get_nlp_result(author_string)
    data = JSON.parse(nlp_result)
    data['sentences'][0]['tokens'].chunk do |token|
      token['ner'] == 'PERSON' ? true : nil
    end.map do |v, tokens|
      tokens.map {|token| token['word'] }.join(' ')
    end + extra
  end
end
