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
  property :admin, String
end

DataMapper.auto_upgrade!

get '/' do
  username = cookiecheck(request.cookies["MainSiteKey"])
  if !username
      return <<-EOL
      <title>Basic Timeclockiness</title>
      <body>You must log in:<br/>
      <form method=post action="loginsubmit" />
    Username:<br/>
      <input type="text" name="username" /><br/>
    Password:<br/>
      <input type="text" name="password" />
      <input type="submit" value="Log in" />
      </form>
      </body>
      EOL
  else
  punchstate=getstate(username)

  return <<-EOL
  <title>Basic Timeclockiness</title>
  <body>
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
  return "Punch #{punchstate} for #{username} successful!"
end

post '/loginsubmit' do
  username=params[:username]
  password=params[:password]
  passcheck(username,password)
  redirect '/'

end


get '/admin' do

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
  if !passinfo
    redirect '/'
  end
  if Digest::SHA1.hexdigest(attempt) == passinfo.password
    timestamp=Time.now.strftime("%Y%m%d%H%M%S")
    uniquestamp = username << timestamp
    digest = Digest::MD5.hexdigest(uniquestamp)
    response.set_cookie("MainSiteKey", {:value => digest, :expiration => Time.now + 600})
    passinfo.update(:cookie => digest)
    return "success"
  end
end