require 'oga'
require 'nokogiri'
require 'open-uri'

class Forum
  attr_accessor :week
  MESSAGE_BODY_CSS = 'div.sharedContentBody.visualIEFloatFix.forumTopicMessageBody'
  def parse_thread(url)
    doc = Nokogiri::HTML(open(url))
    pages = doc.css('#forumTopicTopPagination > div > a').map { |e| e.attribute('href') }
    posts = doc.css('#forumTopicMessages > div.forumTopicMessageRowContainer > div.forumTopicMessageRow.forumTopicMessageBodyRow')
    op    = posts.shift.css(MESSAGE_BODY_CSS).text
    @week = op.split('Week ')[1].split.first.to_i
    miles = posts_to_hash_array(posts)
    miles += pages.map do |page|
      doc = Nokogiri::HTML(open(page))
      posts = doc.css('#forumTopicMessages > div.forumTopicMessageRowContainer > div.forumTopicMessageRow.forumTopicMessageBodyRow')
      posts_to_hash_array(posts)
    end.flatten
    miles.sort do |a,b|
      a[:user].downcase <=> b[:user].downcase
    end
  end

  private
    def posts_to_hash_array(posts)
      # take in an array of posts, return an array of hashes {user: username, miles: {'1': 21.2, '2': 32.5}}
      posts.map do |post|
        author = post.css('div.userDisplayname > a:nth-child(1)').text
        text = post.css("#{MESSAGE_BODY_CSS} > p:nth-child(1)").text.strip.gsub("\u00A0", '')
        if text.empty?
          text = post.css(MESSAGE_BODY_CSS).text.strip.gsub("\u00A0", '')
        end
        next nil if text.empty?
        player, week, miles = text.split(',').map(&:strip)
        if week.to_i != self.week
          post.css(MESSAGE_BODY_CSS).map { |p| p.text.strip.gsub("\u00A0", '') }
        end
        # if author.downcase != player.downcase
        #   puts author, player
        # end
        {user: player, miles: miles.to_f}
      end
    end
  # end private section
end


url = 'http://community.runnersworld.com/topic/2015in2015-week-2-post-em'

miles = Forum.new.parse_thread(url)

miles
# puts miles.select{ |h| h[:miles].empty? }.map { |h| h[:user] }
puts miles
users = miles.map { |h| h[:user] }
puts users.uniq.sort == users.sort
puts miles.length
# puts miles.uniq.length
