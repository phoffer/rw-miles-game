class MyApp < Sinatra::Base
  before do
    @js = []
    @css = []
  end
  before do
    @game = Game.find_by(year: Time.now.year)
  end
  get '/' do
    @week = @game.current_week
    @summary = @week.summary
    # @scores = @weeks.team_scores
    @teams = @game.teams
    @title = '2015in2105 Scoreboard for'
    haml :main
  end
  get '/week/:number' do |number|
    @week = @game.weeks.find_by(number: number.to_i)
    @summary = @week.summary
    # @scores = @weeks.team_scores
    @teams = @game.teams
    @title = '2015in2105 Scoreboard for'
    haml :main
  end


  get '/admin/update_scores' do
    @game.current_week.update_scores
    redirect '/'
  end

  get '/admin/update' do
    @game.update
    redirect '/'
  end

  get '/admin/check_for_new_week' do
    @game.check_for_new_week
    redirect '/'
  end

end
