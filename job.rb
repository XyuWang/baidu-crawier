require 'rubygems'
require 'bundler/setup'

require 'byebug'
require './database'
require 'nokogiri'
require 'open-uri'

def analy blocks
  blocks.each do |block|
    link = block.css "h3 a"
    next if link.blank?
    
    href = link.attr("href").value
    if href.include? 'www.baidu.com/link?url='
      uri = URI.parse href
      response = Net::HTTP.get_response(uri)
      href = response['location']
    end
    title = link.text
    next if title.blank?
    puts "#{title} #{href}"
    Thread.current['name'].links.create! title: title, href: href
  end
end

def process   
  loop do
    $mutex.synchronize do
      if Name.uncompleted.blank?
        Thread.current['wait'] = true
      else
        Thread.current['wait'] = false
        Name.transaction do
          Thread.current['name'] = Name.uncompleted.first
          Thread.current['name'].update completed: true
          Thread.current['name'].save
        end      
      end
    end
    
    if Thread.current['wait']
      sleep 1
      Thread.current['retry'] ||= 0 
      Thread.current['retry'] += 1
      if Thread.current['retry'] < 10
        puts '线程正在等待..'
        next
      else
        puts '线程执行完毕.'
        return
      end
    end
    
    Thread.current['retry'] = 0 
    
    puts "当前: #{Thread.current['name'].id} #{Thread.current['name'].name}"
    url = URI(URI.encode("http://www.baidu.com/s?wd=#{Thread.current['name'].name}"))
    html = Nokogiri::HTML(open(url))

    blocks = html.css '.result.c-container'
    analy blocks

    blocks = html.css '.result-op.c-container'
    analy blocks

    next if Name.count > N
    
    other_links = html.css '#rs table th a'

    other_links.each do |link|
      title = link.text
      puts "新增加: #{title}"
      Name.create name: title
    end
  end
  rescue StandardError => e
#    byebug
    Name.transaction do
      Thread.current['name'].links.destroy_all
      Thread.current['name'].update completed: false
      Thread.current['name'].save
    end
    retry
end

#Name.destroy_all
$mutex = Mutex.new
N = 100000
key = '计算机'
Name.create name: key unless Name.exists? name: key

threads = []
5.times do
  sleep 1
  threads << Thread.new do
    process
  end
end

threads.each do |thread|
  thread.join
end
