# TimeClock V2
# Basic timeclock functionality

require 'rubygems'
require 'sinatra'
require 'dm-core'
require 'dm-migrations'
require 'digest/sha1'

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

end


# Checks for a cookie, returns a username
def cookiecheck(sessioncookie)

  whoitbe = User.first(:cookie => sessioncookie)
  if whoitbe
    loggedusername = whoitbe.username
    return loggedusername
  end

end

# Checks for current punch state and returns the opposite
def getstate(username)
  punchstate=''
    lastpunch = Punch.all(:username => username)
    if !lastpunch.last
      punchstate='IN'
    else
      if lastpunch.last.punchstate == 'IN'
        punchstate = 'OUT'
        else
        punchstate = 'IN'
      end
    end

  return punchstate
end

def passcheck(username,attempt)
  passinfo=User.first(:username => username)
  unless passinfo
    setalert("Username or password are incorrect")
    redirect '/'
  end
  if Digest::SHA1.hexdigest(attempt) == passinfo.password
    timestamp=Time.now.strftime("%Y%m%d%H%M%S")
    uniquestamp = username << timestamp
    digest = Digest::MD5.hexdigest(uniquestamp)
    response.set_cookie("MainSiteKey", {:value => digest, :expires => Time.now + 300})
    passinfo.update(:cookie => digest)
    return "success"
  end
end

def alert()
  alert = request.cookies["Alert"]
  response.set_cookie("Alert", {:value => "", :expires => Time.now + 600})
  return alert
end

def setalert(alert)
  response.set_cookie("Alert", {:value => alert, :expires => Time.now + 2})
end

def listbuilder()
	userlist=User.all()
	usersform ="<form method=post action=\"moduser\" /><table border=\"0\"><tr><td>Username</td><td>Admin</td><td>Delete</tr>"
	userlist.each do |c|
		if c.admin
			checker = "CHECKED"
		else
			checker =""
		end
		usersform << "<tr><td>" << c.username << "</td>"
		usersform << "<td><center><input type=\"checkbox\" name=\"" << c.username << "\"  " << checker << "></td>"
		usersform << "<td><center><input type=\"checkbox\" name=\"" << c.username << "delete\" ></td></tr>"
	end
	usersform << "</table><br/><input type=\"submit\" value=\"Modify users\" /></form>"
	return usersform
end

post '/moduser' do

dicks=Array.new

query = User.all
query.each do |c|
  dicks << c.username
end

params[:dicks].each_with_index do |c,i| 
  tempthing = User.all(:username => i)
  if c == "on"
    tempthing.admin = true
  else
    tempthing.admin = false
  end
  tempthing.save
end
setaler("User modification successful")
redirect '/admin'
end