# TimeClock V2
# Basic timeclock functionality

require 'rubygems'
require 'sinatra'
require 'dm-core'
require 'dm-migrations'
require 'digest/sha1'

require 'tc_functions'

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

get '/' do
  username = cookiecheck(request.cookies["MainSiteKey"])
  if !username
      return <<-EOL
      <title>Basic Timeclockiness</title>
      <body>
      <h1>#{alert()}</h1><br/>
      You must log in:<br/>
      <form method=post action="loginsubmit" />
    Username:<br/>
      <input type="text" name="username" /><br/>
    Password:<br/>
      <input type="password" name="password" />
      <input type="submit" value="Log in" />
      </form>
      </body>
      EOL
  else
  punchstate=getstate(username)
  return <<-EOL
  <title>Basic Timeclockiness</title>
  <body>
  <h1>#{alert()}</h1><p>
  <form method=post action="submit" />
  <input type="submit" value="Punch #{username} #{punchstate}" />
  </form>
  </body>
  EOL
end
end

post '/submit' do

  username = cookiecheck(request.cookies["MainSiteKey"])
  if !username
    redirect '/'
  end
  punchstate = getstate(username)

  Punch.create(
    :username =>  username,
    :punchtime  =>  Time.now,
    :punchstate =>  punchstate
  )
  setalert("Punch #{punchstate} for #{username} successful!")
  redirect '/'
end

post '/loginsubmit' do
  username=params[:username]
  password=params[:password]
  passcheck(username,password)
  redirect '/'
end


get '/admin' do
  username = cookiecheck(request.cookies["MainSiteKey"])
  if !username
    redirect '/'
  end
  admininfo=User.first(:username => username)
  if admininfo.admin
    return <<-EOL
    <title>TimeClock Administration</title>
    <body>
    <h1>ADMINISTRATION!<br/>#{alert()}<br/></h1>
    <form method=post action="createuser" />
    <label for="username">Username:</label><br/>
      <input type="text" name="username" id="username"/><br/>
    <label for="password">Password:</label><br/>
      <input type="text" name="password" id="password"/><br/>
      <input type="checkbox" name="admin" value="true" id="admin"/><label for="admin">Admin?</label><br/>
      <input type="submit" value="Create user" />
      </form>
      #{listbuilder()}
    </body>


EOL
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