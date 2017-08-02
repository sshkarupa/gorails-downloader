# frozen_string_literal: true

# !/usr/bin/ruby
require 'rss'

EMAIL    = ENV.fetch('GORAILS_EMAIL')
PASSWORD = ENV.fetch('GORAILS_PASSWORD')
OLD_EPISODE = 183

puts 'GoRails Downloader'

rss_string = open(
  'https://gorails.com/episodes/pro.rss',
  http_basic_authentication: [EMAIL, PASSWORD]
).read

rss = RSS::Parser.parse(rss_string, false)

videos_urls = rss.items.map do |it|
  {
    title: it.title,
    url: it.enclosure.url,
    filename: it.title.strip.downcase.gsub(/\W+/, '-') + '.' + it.enclosure.url.split('.').last,
    episode: /[0-9]{1,5}-/.match(it.enclosure.url)[0].delete('-'),
    size: it.enclosure.length / (1024 * 1024)
  }
end.reverse

puts "Found #{videos_urls.size} videos on GoRails"

videos_urls.reject! { |k| k[:episode].to_i <= OLD_EPISODE } # remove old edisode

videos_filenames = videos_urls.map { |k| k[:episode] + '-' + k[:filename] }
existing_filenames = Dir.glob('**{,/*/**}/*.mp4').map { |f| f.gsub('videos/', '') }
existing_filenames.uniq!
missing_filenames = videos_filenames - existing_filenames
puts "Downloading #{missing_filenames.size} missing videos"

missing_videos_urls = videos_urls.select do |video_url|
  missing_filenames.any? do |filename|
    (video_url[:episode] + '-' + video_url[:filename]).match filename
  end
end

missing_videos_urls.each do |video_url|
  filename = File.join('videos', video_url[:episode] + '-' + video_url[:filename])
  puts <<-EOF
  (#{video_url[:episode]}/#{videos_urls.last[:episode]}) \
  Downloading '#{video_url[:title]}' (#{video_url[:size]}mb)
  EOF
  `curl --progress-bar #{video_url[:url]} -o #{filename}.tmp`
  `mv #{filename}.tmp #{filename}`
end

puts "Finished downloading #{missing_videos_urls.size} videos"
