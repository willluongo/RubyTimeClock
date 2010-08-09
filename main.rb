# TimeClock V2
# Basic timeclock functionality

require 'rubygems'
require 'sinatra'
require 'dm-core'
require 'dm-migrations'
require 'digest/sha1'
require 'haml'

require 'tc_functions'
require 'sinatra/reloader'

# DataMapper.setup(:default, 'mysql://rubytest:rubytestpass@local.derbserv.org/rubytest')
DataMapper.setup(:default, 'sqlite3:timeclock.db')

class Punch
  include DataMapper::Resource
  property :id, Serial
  property :username, String
  property :punchtime, DateTime
  property :punchstate, String
end

class User
  include DataMapper::Resource
  property :id, Serial
  property :username, String
  property :password, String
  property :cookie, String
  property :admin, Boolean
end

DataMapper.auto_upgrade!

class Dummy
  def admin
    @admin
  end
  def admin=(admin)
    @admin = admin
  end
end

# get '/' do
#   username = cookiecheck(request.cookies["MainSiteKey"])
#   if !username
#       return <<-EOL
#       <title>Basic Timeclockiness</title>
#       <body>
#       <h1>#{alert()}</h1><br/>
#       You must log in:<br/>
#       <form method=post action="loginsubmit" />
#     Username:<br/>
#       <input type="text" name="username" /><br/>
#     Password:<br/>
#       <input type="password" name="password" />
#       <input type="submit" value="Log in" />
#       </form>
#       </body>
#       EOL
#   else
#   punchstate=getstate(username)
#   return <<-EOL
#   <title>Basic Timeclockiness</title>
#   <body>
#   <h1>#{alert()}</h1><p>
#   <form method=post action="submit" />
#   <input type="submit" value="Punch #{username} #{punchstate}" />
#   </form>
#   </body>
#   EOL
# end
# end

get '/' do
  @title="Timeclock"
  @username = cookiecheck(request.cookies["MainSiteKey"])
  if !@username
    @title="Timeclock - Log In"
    @alert=alert()
    @admininfo=Dummy.new
    @admininfo.admin = false
    haml :loginpage
  else
    @punchstate=getstate(@username)
    @username = cookiecheck(request.cookies["MainSiteKey"])
    @alert=alert()
    @admininfo=User.first(:username => @username)
    
    haml :mainpage
  end
end

get '/logout' do
  response.set_cookie("MainSiteKey", {:value => "", :expires => Time.now})
  setalert("Succesfully logged out.")
  redirect '/'
end



post '/submitpunch' do
  return params[:textings]
end




post '/submit' do
  @username = cookiecheck(request.cookies["MainSiteKey"])
  if !@username
    redirect '/'
  end
  @punchstate = getstate(@username)

  Punch.create(
    :username =>  @username,
    :punchtime  =>  Time.now,
    :punchstate =>  @punchstate
  )
  setalert("Punch #{@punchstate} for #{@username} successful!")
  redirect '/'
end

post '/loginsubmit' do
  username=params[:username]
  password=params[:password]
  passcheck(username,password)
  redirect '/'
end


get '/admin' do
  @username = cookiecheck(request.cookies["MainSiteKey"])
  if !@username
    redirect '/'
  end
  @admininfo=User.first(:username => @username)
  if @admininfo.admin
    haml :adminpage
  else
    # return "You are not logged in as an administrative user."
    setalert("You are not logged in as an administrative user.")
    redirect '/'
   end

end

post '/createuser' do
	logincheck = cookiecheck(request.cookies["MainSiteKey"])
  if !logincheck
  	setalert("Login expired")
    redirect '/'
  end
  username = params[:username]
  password = params[:password]
  if params[:admin] == 'true'
    admin = true
  else
    admin = false
  end
    
  if !(username == '') && !(password=='')
  User.create(
  :username => username,
  :password => Digest::SHA1.hexdigest(password),
  :cookie => "none",
  :admin => admin
  )
  setalert("User successfully created!")
  else
    setalert("Username and password fields are required.")
  end
  redirect '/admin'
end


get '/report' do
  username = cookiecheck(request.cookies["MainSiteKey"])
  if !username
    redirect '/'
  end
  list_punches = Punch.all(:username => username)
  list = ""
  list_punches.each do |stuff|
    stuff.punchtime
  list << "#{stuff.username} punched #{stuff.punchstate} on #{stuff.punchtime.strftime(fmt='%F')} at #{stuff.punchtime.strftime(fmt='%T')}<br/>"
  end
  return list
end

post '/moduser' do
  query = User.all(:fields => [:id, :username])
  listem = Array.new
  newlist = Array.new

  query.each do |c|
    listem << c.username
  end

listem.each do |username|
  tempthing = User.first(:username => username)
  if params[username]
    tempthing.admin = true
  else
    tempthing.admin = false
  end
  tempthing.save
end

listem.each do |username|
  temp_User = User.first(:username => username)
  temp_param = username + "delete"
  if params[temp_param]
    temp_User.destroy!
    temp_punches = Punch.all(:username => username)
    temp_punches.destroy!
  end
end

  setalert("User modification successful")
  redirect '/admin'
end