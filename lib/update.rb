# triggers an update, can be run separately as a scheduled task
require 'open-uri'
Thread.new { open('https://rw2015in2015.herokuapp.com/admin/update') }
sleep 0.5
exit