require 'active_support/cache'
require 'digest'
require 'tempfile'
require 'stanford-core-nlp'

StanfordCoreNLP.jvm_args = ['-Xms1024M', '-Xmx2048M']
StanfordCoreNLP.jar_path = '/Users/brian/github/subvertallchris/graphnote/bin/stanford/'
StanfordCoreNLP.model_path = '/Users/brian/github/subvertallchris/graphnote/bin/stanford/'
STANFORD_CORE_PIPELINE =  StanfordCoreNLP.load(:tokenize, :ssplit, :pos, :lemma, :ner)

CACHE = ActiveSupport::Cache::FileStore.new('nlp_cache')
require 'json'

def get_nlp_result(text)
  file = Tempfile.new('get_nlp_result')
  json_file = File.basename(file.path) + '.json'
  digest = Digest::SHA256.digest(text)
  CACHE.fetch(digest) do
    File.open(file.path, 'w') { |f| f << text }
    #command = "java -cp "*" -Xmx2g edu.stanford.nlp.pipeline.StanfordCoreNLP -annotators tokenize,ssplit,pos,lemma,ner,parse,dcoref -file input.txt -outputFormat json"
    command = "java -cp \"*\" -Xmx2g edu.stanford.nlp.pipeline.StanfordCoreNLP -annotators tokenize,ssplit,pos,lemma,ner -file #{file.path} -outputFormat json"
    system("#{command} 2> /dev/null")
    File.read(json_file)
  end
rescue Errno::ENOENT
ensure
  `rm #{json_file} 2> /dev/null`
end

def get_nlp_result(text)
  digest = Digest::SHA256.digest(text)
  CACHE.fetch(digest) do
    text = StanfordCoreNLP::Annotation.new(text)
    STANFORD_CORE_PIPELINE.annotate(text)
    sentences_data = text.get(:sentences).map do |sentence|
      tokens_data = sentence.get(:tokens).map do |token|
        {'ner' => token.ner, 'word' => token.word }
      end
      {tokens: tokens_data}
    end
    {sentences: sentences_data}.to_json
  end
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
    return if nlp_result.nil?

    data = JSON.parse(nlp_result)
    data['sentences'][0]['tokens'].chunk do |token|
      token['ner'] == 'PERSON' ? true : nil
    end.map do |v, tokens|
      tokens.map {|token| token['word'] }.join(' ')
    end + extra
  end
end
