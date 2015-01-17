# encoding: utf-8
module HTML
  def javascripts *scripts
    javascripts = (settings.javascripts + scripts + @js).uniq
    javascripts.map do |script|
      "<script src='#{path_to script}'></script>"
    end.join("\n")
  end
  def javascripts_inline *scripts
    javascripts = (scripts).uniq
    javascripts.map do |script|
      "<script src='#{path_to script}'></script>"
    end.join("\n")
  end
  def stylesheets *sheets
    stylesheets = (settings.stylesheets + sheets + @css).uniq
    stylesheets.map do |sheet|
      "<link href='/css/#{sheet}.css' rel='stylesheet' type='text/css' />"
    end.join("\n")
  end
  def path_to script
    case script
      when :jquery     then   'https://ajax.googleapis.com/ajax/libs/jquery/1.7.1/jquery.min.js'
      when :rightjs    then   'http://cdn.rightjs.org/right-2.3.0.js'
      when :backbone   then   'http://cdnjs.cloudflare.com/ajax/libs/backbone.js/0.9.0/backbone-min.js'
      when :underscore then   'http://cdnjs.cloudflare.com/ajax/libs/underscore.js/1.3.1/underscore-min.js'
      else '/js/' + script.to_s + '.js'
    end
  end
end
module Routes
  def add_resources(*args)
    args.each do |a|
      case a
      when :something
        js :something
        css :something
      end
    end
  end
  def js *scripts
    @js ||= []
    @js += scripts
  end
  def css *sheets
    @css ||= []
    @css += sheets
  end
end
