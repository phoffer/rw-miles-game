if __FILE__ == $0
  require 'mongoid'
  Mongoid.load!(File.dirname(__FILE__) + '/mongoid.yaml')
end
require 'open-uri'
require 'simple-rss'
require 'rss'
require 'rubyXL'
require 'nokogiri'

class Game # full year of the game
  # http://community.runnersworld.com/forum/team-challenges?rss=true
  include Mongoid::Document
  has_many :teams
  has_many :weeks

  FORUM_RSS = 'http://community.runnersworld.com/forum/team-challenges?rss=true'


  field :year,              type: Integer
  field :current,           type: Integer # current changes whenever a week opens
  field :closes_at_week_0,  type: Time
  field :current_count,     type: Integer

  def current_week
    self.weeks.find_or_create_by(number: current)
  end
  def next_week
    self.weeks.find_or_create_by(number: self.current + 1)
  end
  def update
    if Time.now > current_week.closes_at
      check_for_new_week
    elsif current_week.status == 1
      current_week.update_scores
    else
      # TBD
    end
  end
  def check_for_new_week
    if next_week.check_for_thread
      current_week.finalize
      next_week.update_attribute(:status, 1)
      self.update_attribute(:current, next_week.number)
      current_week.update_scores
    end
  end
  def advance_week!
    self.inc(current: 1)
  end
  def import_teams(xlsx = '../misc/teams.xlsx')
    workbook = RubyXL::Parser.parse(xlsx)
    worksheet = workbook[2]
    sheetdata = worksheet.extract_data
    update_at = sheetdata.shift
    header    = sheetdata.shift

    t = Team.new
    teams = {}
    ir_hash = {status: 1}
    people = sheetdata.map do |arr|
      next nil if arr.try(:first).nil?
      team_name = arr[1]
      next nil if ['Individual', 'Pinch Hitter'].include? team_name
      t = team_name == t.name ? t : self.teams.find_or_create_by(name: team_name)
      # p = t.players.create(name: arr.first.downcase, miles: nil)
      hash = {name: arr.first.downcase, miles: nil, team: t.id}.merge(arr[6] == 'Yes' ? ir_hash : {} )
    end.compact
    Player.create(people)
  end
end

class Team
  include Mongoid::Document
  belongs_to :game
  has_many :miles
  has_many :players

  field :name

  def miles_for_week(w)
    @miles ||= self.players.not_IR.map{ |p| p.miles.find_by(week_id: Week.find_by(number: w.number).id, player_id: p.id) || p.miles.new  }.sort_by(&:total).reverse
  end
  def display_for_week(w)
    @display ||= (miles_for_week(w) + self.players.on_IR.map { |p| p.miles.find_or_create_by(week_number: w.number, on_ir: true) }).map { |m| [m.player.name, m.display] }.to_h
  end
  def week_summary(w)
    miles = miles_for_week(w)
    {miles: miles.map(&:total).inject(:+).round(2), score: score_for_week(w), display: display_for_week(w), posters: "#{self.miles.for_week(w.number).count}/#{self.players.count}"}
  end
  def score_for_week(w)
    return @score if @score
    miles = self.miles_for_week(w).map(&:total)
    display = self.miles_for_week(w).map(&:display)
    factor = display.include?(Mile::NOPOST_DISPLAY) ? 1.0 : 1.1
    # puts miles.values.take(w.count)
    @score = (miles.take(w.count).sum * factor).round(2)
  end

end

class Week
  include Mongoid::Document
  belongs_to :game
  has_many :miles
  has_and_belongs_to_many :matchups
  # MESSAGE_BODY_CSS = 'div.sharedContentBody.visualIEFloatFix.forumTopicMessageBody' # standard thread
  MESSAGE_BODY_CSS = 'div.sharedContentBody.visualIEFloatFix.postBody'
  SPLIT_REGEX = ','

  field :number,      type: Integer
  field :status,      type: Integer,  default: 0 # {0 => not open, 1 => open, 2 => closed}
  field :top_count,   type: Integer
  field :thread_url,  type: String
  field :scores,      type: Hash
  field :updated_at,  type: Time,     default: -> { Time.now - 365 * 24 * 3600 }

  def count
    self.top_count or self.game.current_count
  end

  def closes_at
    self.game.closes_at_week_0 + self.number.weeks
  end
  def check_for_thread
    rss = SimpleRSS.parse(open(Game::FORUM_RSS))
    thread = rss.items.detect{ |item| item.title.include?("#{self.game.year}in#{self.game.year}") && item.title.include?("Week_#{self.number}_-_Post") }
    thread && self.update_attributes(thread_url: thread.link.gsub('/topic/', '/printer-friendly-topic/'), status: 1)
  end
  def update_scores
    # parse thread, update players' miles
    check_for_thread unless self.thread_url
    parse_thread unless self.updated_at > self.closes_at
    # self.updated_at = Time.now
    # check if thread should be "closed" now, finalize
    # finalize
  end
  def finalize # when thread is closed
    update_scores unless caller_locations(1,1)[0].label == 'update_scores'

    # self.update_attribute(:status, 2)
  end
  def parse_thread
    doc = Nokogiri::HTML(open(self.thread_url))
    pages = doc.css('#forumTopicTopPagination > div > a').map { |e| e.attribute('href') }
    # posts = doc.css('#forumTopicMessages > div.forumTopicMessageRowContainer > div.forumTopicMessageRow.forumTopicMessageBodyRow') # standard
    posts = doc.css('div.printerFriendlyPostWrapper.solidBorderedWrapper')
    op    = posts.shift.css(MESSAGE_BODY_CSS).text
    # @week = op.split('Week ')[1].split.first.to_i
    miles = posts_to_hash_array(posts)
    Player.on_IR.each{|p| p.miles.find_or_create_by(week_number: self.number, week_id: self.id, team_id: p.team.id, on_ir: true) }
    update_attribute(:updated_at, Time.now)

    # miles += pages.map do |page|
    #   doc = Nokogiri::HTML(open(page))
    #   posts = doc.css('#forumTopicMessages > div.forumTopicMessageRowContainer > div.forumTopicMessageRow.forumTopicMessageBodyRow')
    #   posts_to_hash_array(posts)
    # end.flatten

  end
  def team_scores
    self.game.teams.map { |t| [t.name, t.score_for_week(self)] }.sort_by(&:last).reverse.to_h
  end
  def summary
    self.game.teams.map { |t| [t.name, t.week_summary(self)] }.sort{ |a,b| b.last[:score] <=> a.last[:score]}.to_h
  end

  private
    def posts_to_hash_array(posts)
      # take in an array of posts, return an array of hashes {user: username, miles: {'1': 21.2, '2': 32.5}}
      posts.map do |post|
        # author = post.css('div.userDisplayname > a:nth-child(1)').text
        text = post.css("#{MESSAGE_BODY_CSS} > p:nth-child(1)").text.strip.gsub("\u00A0", '')
        if text.empty?
          text = post.css(MESSAGE_BODY_CSS).text.strip.gsub("\u00A0", '')
        end
        next nil if text.empty?
        player, week, miles = text.split(SPLIT_REGEX).map(&:strip)
        if week.to_i != self.number
          post.css(MESSAGE_BODY_CSS).map { |p| p.text.strip.gsub("\u00A0", '') } # find correct week
        end
        return if text['deadline'] && text['passed']
        # if author.downcase != player.downcase
        #   puts author, player
        # end
        p = Player.find_by(name: player.downcase)
        if p
          m = p.miles.find_or_create_by(week_number: self.number, week_id: self.id, team_id: p.team.id)
          m.update_attribute(:total, miles.to_f)
          nil
        else
          {user: player, miles: miles.to_f}
        end
      end.compact
    end
  # end of private section
end

class Player
  include Mongoid::Document
  belongs_to :team
  has_many :miles do
    def for_week(n)
      where(week_number: n).first || Mile.new
    end
  end

  scope :week,    ->(n) { where(week_number: n) }
  scope :not_IR,  ->    { where(status: 0) }
  scope :on_IR,   ->    { where(status: 1) }

  field :name
  field :status,  type: Integer, default: 0 # 0 active, 1 IR, 2 ?

  def on_ir?
    self.status == 1
  end
end

class Mile
  include Mongoid::Document

  NOPOST_DISPLAY = 'Not Posted'
  IR_DISPLAY = 'IR'
  belongs_to :player
  belongs_to :team
  belongs_to :week

  scope :for_week, ->(n) { where(week_number: n) }

  field :total,       type: Float,    default: 0.0
  field :week_number, type: Integer
  field :on_ir,       type: Boolean,  default: false

  def display
    return IR_DISPLAY if self.on_ir or self.player.on_ir?
    self.week_id ? self.total : NOPOST_DISPLAY
    # because this is used for calculations, if there aren't enough posts to score it will blow up
  end
  def posted?
    !!self.week_id
  end

end
class Matchup
  include Mongoid::Document
  has_and_belongs_to_many :weeks # == 2 weeks
  # this is it I guess?
  # add some methods
end

