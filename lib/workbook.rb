require 'rubyXL'
# require 'google-drive'
require 'supermodel'
require 'nokogiri'
require 'open-uri'

class Team < SuperModel::Base
  has_many :players

  def order!
    players_with_miles.sort { |a, b| b.miles <=> a.miles }
  end
  def players_with_miles
    @posted = self.players.to_a.reject{ |p| p.miles.nil? }
  end
  def score
    base = order!.take(13).map(&:miles).inject(:+)
    base *= @posted.length == self.players.length ? 1.1 : 1.0
    @score = base.round(2)
  end
  # def print
  #   players.sort { |a, b| b.score <=> a.score }.map { |e| {name: e.name, miles: e.score, posted: "#{e.players_with_miles.length}/#{e.players.length}" } }
  # end
  def length
    players.length
  end
  def self.score
    all.sort { |a, b| b.score <=> a.score }
  end
  def self.print_score
    name_length = all.map.map(&:name).map(&:length).max
    all.each
    header = 'Team'.ljust(name_length + 3) << 'Miles   ' << 'Posted'
    header = 'Miles   ' << 'Posted   ' << 'Team'.ljust(name_length + 3)
    puts header
    puts '-' * header.length
    # score.each { |t| puts "#{t[:name].ljust(name_length)}   #{t[:miles].to_s.ljust(6)}  #{t[:posted]}" }
    score.each do |t|
      h =  {name: t.name, miles: t.score, posted: "#{t.players_with_miles.length}/#{t.players.length}" }
      puts "#{h[:miles].to_s.ljust(6)}  #{h[:posted]} #{h[:name].ljust(name_length)}"
      # t.players.sort { |a,b| b.miles.to_f <=> a.miles.to_f }.each { |p| puts p.to_s }
      # puts '---------'
    end
  end
end

class Player < SuperModel::Base
  belongs_to :team

  def to_s
    "#{miles ? miles.round(2).to_s.ljust(5) : 'No Post'} #{name}"
  end
end
class Forum
  attr_accessor :week
  MESSAGE_BODY_CSS = 'div.sharedContentBody.visualIEFloatFix.forumTopicMessageBody'
  SPLIT_REGEX = /(\s|,)/
  SPLIT_REGEX = ','
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
        puts text if text['deadline'] && text['passed']
        next false if text['deadline'] && text['passed']
        player, week, miles = text.split(SPLIT_REGEX).map(&:strip)
        if week.to_i != self.week
          post.css(MESSAGE_BODY_CSS).map { |p| p.text.strip.gsub("\u00A0", '') }
        end
        # if author.downcase != player.downcase
        #   puts author, player
        # end
        p = Player.find_by_name(player.downcase)
        if p
          p.update_attribute(:miles, miles.to_f)
          nil
        else
          {user: player, miles: miles.to_f}
        end
      end.compact.take_while{ |a| a != false }
    end
  # end private section
end

class Game
  attr_accessor :teams_book, :posting_thread, :matchups_book
  def initialize(teams_book:, posting_thread:, matchups_book:)
    @teams_book = teams_book
    @posting_thread = posting_thread
    @matchups_book = matchups_book
    parse_teams
  end
  def parse_teams
    workbook = RubyXL::Parser.parse(@teams_book)
    worksheet = workbook[2]
    sheetdata = worksheet.extract_data
    update_at = sheetdata.shift
    header    = sheetdata.shift

    sheetdata.each do |arr|
      next if arr.try(:first).nil?
      team_name = arr[1]
      next if ['Individual', 'Pinch Hitter'].include? team_name
      t = Team.find_by_attribute(:name, team_name) || Team.create(name: team_name)
      p = Player.create(name: arr.first.downcase, team: t, miles: nil)
      p.update_attribute(:status, 1) if arr[6] == 'Yes'
    end
  end
  def parse_miles
    miles = Forum.new.parse_thread(@posting_thread)
  end

end

puts RUBY_VERSION
url = 'http://community.runnersworld.com/topic/2015in2015-week-2-post-em'

g = Game.new(teams_book: "../misc/game.xlsx", posting_thread: url, matchups_book: '')
arr = g.parse_miles
# puts arr.first
puts arr.sort{ |a,b| a[:user].downcase <=> b[:user].downcase }.map { |h| {user: h[:user], miles: h[:miles]} }
puts arr.length

puts Time.now
puts Player.all.sort { |a,b| a.name <=> b.name }.map { |p| {user: p.name, miles: p.miles} }
no_miles = Player.find_all_by_attribute(:miles, nil)
# puts no_miles.map(&:name).sort
# puts Player.find_by_name('phoffer').team.order!.map(&:to_s)
# puts Team.score
Team.print_score#.each { |t| puts "#{t[:name].ljust(name_length)}   #{t[:miles].to_s.ljust(6)}  #{t[:posted]}" }

