require "ikku"
require "logger"
require "open-uri"
require "rss"
require "time"
require "twitter"

reviewer = Ikku::Reviewer.new

urls = %w[
  https://www.nhk.or.jp/rss/news/cat0.xml
  https://www.news24.jp/rss/index.rdf
  https://www.asahi.com/rss/asahi/newsheadlines.rdf
  http://www3.asahi.com/rss/animal.rdf
  https://mainichi.jp/rss/etc/mainichi-flash.rss
  https://assets.wor.jp/rss/rdf/nikkei/news.rdf
  https://assets.wor.jp/rss/rdf/reuters/top.rdf
  https://assets.wor.jp/rss/rdf/ynnews/news.rdf
]
  #https://assets.wor.jp/rss/rdf/yomiuri/latestnews.rdf

last = Time.now - 30 * 60 # 30 min

logger = Logger.new(STDERR)

articles = urls.flat_map do |url|
  logger.debug(url)
  feed = RSS::Parser.parse(URI.open(url)) rescue next
  feed.items.select { |i| i.date > last }.map { |i| [i.title, i.link] }
end.compact

# Do some cleansing
articles.each do |article|
  article[0].gsub!(/　\d+\/\d+ \d+:\d+更新$|^[^：:]{,10}[：:]|=[^=]{,10}$|^【[^】]+】|^[^）)]{,10}[）)]/, '')
  article[1].gsub!(/\?.*$/, '')
end
logger.info(articles)

detected = articles.select do |article|
  song = reviewer.find(article[0])&.phrases&.join

  next unless song
  next if song.match?(/[０-９]/)

  article.push(song)
end
logger.info(detected)

twitter = Twitter::REST::Client.new do |config|
  config.consumer_key = ENV["TWITTER_CONSUMER_KEY"]
  config.consumer_secret = ENV["TWITTER_CONSUMER_SECRET"]
  config.access_token = ENV["TWITTER_ACCESS_TOKEN"]
  config.access_token_secret = ENV["TWITTER_ACCESS_TOKEN_SECRET"]
end

detected.each do |article|
  begin
    tweet = twitter.update("#{article[2]} #{article[1]}")
  rescue => e
    logger.error(e)
  else
    logger.info(tweet.text)
  end
end
