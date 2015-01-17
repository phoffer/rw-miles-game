# encoding: utf-8

# have a class here to deal with the spreadsheets?

# class for Person?

# class to parse forum thread

# Requirements:
  # Interface with offical g-doc
  # Interface with our g-doc
  # Parse posting threads
    # ignore posts for previous week. know the player with miles, maybe not the thread poster
  # Cache current status of posting threads / matchups / totals
  # Know the current week / game status
  # Deal with people - matching across spreadsheets, thread, etc. 
require 'mongoid'
Mongoid.load!(File.dirname(__FILE__) + '/mongoid.yaml')

require_relative 'mongoid'


