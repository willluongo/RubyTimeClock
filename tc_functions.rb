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
  response.set_cookie("Alert", {:value => "", :expires => Time.now})
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