---------------------------------------------------------------------------------------------
-- Applescript for easy invocation of 'pass'
---------------------------------------------------------------------------------------------
--
-- Author: Steffen Vogel <post@steffenvogel.de>
-- Tested with: OS X 10.10 Yosemite
--
-- Installation:
--
--   1. Copy this script to /Library/Scripts/pass.applescript
--
--   2. Use the Automator to create a service which starts the following AppleScript:
--
--        on run {input, parameters}
--	      run script POSIX file "/Library/Scripts/pass.applescript"
--        end run
--
--   3. Install the application 'Notifications Scripting' from:
--        http://www.cooperative-fruitiere.com/notifications/NotificationsScripting.dmg
--
--   4. Go to 'System Settings' -> 'Keyboard' to create a short cut for the service
--       you created before
--   
--   5. Go to 'System settings' -> 'Notifications' -> choose 'Notifications Scripting' 
--       -> and switch from 'Banners' to 'Alerts'
--
---------------------------------------------------------------------------------------------

-- Configuration
property defPass : "root"
property clearAfter : 45
property shellPath : "/opt/local/bin:/usr/local/bin:$PATH"

-- Translation
set lang to user locale of (get system info)
if (lang = "de_DE") then
	set nTitle to "Password-store"
	set nPrompt to "Welches Password wird benštigt?"
	set nClear to "Vergesse"
else -- if (lang = "en")
	set nTitle to "Password-store"
	set nPrompt to "Which password do you want?"
	set nClear to "Forget"
end if

try
	set entity to the text returned of (display dialog nPrompt default answer defPass buttons {"OK"} with title nTitle default button 1)
	set pw to do shell script "export PATH=" & shellPath & "; pass " & entity
	
	set the clipboard to pw
	
	-- Wait until clipboard changed then close notification
	repeat with secsLeft from 0 to clearAfter
		if pw is equal to (the clipboard) then
			tell application "Notifications Scripting"
				set event handlers script path to (path to me)
				display notification nTitle id "pass" message "Password copied to clipboard (" & (clearAfter - secsLeft) & " secs left)" action button nClear with has action button
			end tell
			delay 1
		else
			exit repeat
		end if
	end repeat
on error errMsg
	display dialog errMsg with title nTitle with icon stop
end try

-- Clear clipboard
set the clipboard to ""
closeNotifications()

-- Handle click to notification:
using terms from application "Notifications Scripting"
	on notification activated
		set the clipboard to ""
	end notification activated
end using terms from

-- Close all Notifications
on closeNotifications()
	tell application "System Events"
		tell process "NotificationCenter"
			set theWindows to every window
			repeat with i from 1 to number of items in theWindows
				set this_item to item i of theWindows
				try
					click button 1 of this_item
				end try
			end repeat
		end tell
	end tell
end closeNotifications
