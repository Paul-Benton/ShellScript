#!/bin/bash
##  Created by Shaquir Tannis on 6/12/19
##  Great help from Ian Davidson @iancd addressing Slack's version changes
##  Thanks to owen.pragel and anverhousseini from JamfNation
#### Edited 7/19/19 to address Slack releases.json removal
#### Edited 8/1/19 to address copy issues and point to Slack's RSS feed for latest version
#### Edited 2020-04-27  - Changed so multi number version files work
####			- Changed so Downloads are via RSS feed (downloads page sometimes delays)
####			- Changed so kills always when updating only.
####			- Added Jamf notifiers, reports updated vs installed and version
#### Edited 2020-05-06  - Added download url http request check for 200, Slack RSS was giving bad links.
#### Edited 2020-05-29  - Changed localSlackVersion discovery to be less redundant and better for catching errors

#To kill Slack, Input "kill" in Parameter 4 
# killSlack="$4"
killSlack="kill"

#Find latest Slack version / Pulls Version from Slack for Mac download page
currentSlackVersion=$(/usr/bin/curl -sL 'https://slack.com/release-notes/mac/rss' | grep -m1 -o "Slack-\d*\.\d*\.\d*"  | cut -c 7-)

#Install Slack function
install_slack() {
	
#Slack download variables
#Main downloads page
#slackDownloadUrl=$(curl "https://slack.com/ssb/download-osx" -s -L -I -o /dev/null -w '%{url_effective}')

#slackDownloadUrl=$(/usr/bin/curl -sL 'https://slack.com/release-notes/mac/rss' | grep -m1 -o "https\:\/\/downloads\.slack-edge\.com\/mac_releases\/Slack-\d*\.\d*\.\d*-macOS\.dmg")

#RRS Feed
slackDownloadUrl=$(/usr/bin/curl -sL 'https://slack.com/release-notes/mac/rss' | sed -nE 's|.*(https://downloads.slack-edge.com/.*\.dmg).*|\1|p' | head -1)

dmgName=$(printf "%s" "${slackDownloadUrl[@]}" | sed 's@.*/@@')
slackDmgPath="/tmp/$dmgName"

	
#Kills slack if "kill" in Parameter 4 
#if [ "$killSlack" = "kill" ];
#then
#pkill Slack*
#fi

#Begin Download

downloadavailable=`curl -l -I -s -o /dev/null -w "%{http_code}" $slackDownloadUrl`
if [[ $downloadavailable != 200 ]]; then
	echo "Slack DMG not Reachable, Check Internet Connection error: $downloadavailable"
	exit $downloadavailable

else 

	#Downloads latest version of Slack
	curl -L -o "$slackDmgPath" "$slackDownloadUrl"

	#Mounts the .dmg
	hdiutil attach -nobrowse $slackDmgPath

	#Checks if Slack is still running
	if pgrep '[S]lack' && [ "$killSlack" != "kill" ]; then
		printf "Error: Slack is currently running!\n"
		
	elif pgrep '[S]lack' && [ "$killSlack" = "kill" ]; then
		pkill -9 Slack*
		sleep 5
		if pgrep '[S]lack' && [ "$killSlack" != "kill" ]; then
			printf "Error: Slack is still running!  Please try again later.\n"
			exit 409
		fi
	fi
    
	# Remove the existing Application
		rm -rf /Applications/Slack.app

	#Copy the update app into applications folder
		ditto -rsrc /Volumes/Slack*/Slack.app /Applications/Slack.app

	#Unmount and eject dmg
		mountName=$(diskutil list | grep Slack | awk '{ print $3 }')
		umount -f /Volumes/Slack*/
		diskutil eject $mountName

	#Clean up /tmp download
		rm -rf "$slackDmgPath"
    #update for if check
	localSlackVersion=$(defaults read "/Applications/Slack.app/Contents/Info.plist" "CFBundleShortVersionString")

fi	

}

#Fix Slack ownership function
assimilate_ownership() {
	echo "=> Assimilate ownership on '/Applications/Slack.app'"
	chown -R $(scutil <<< "show State:/Users/ConsoleUser" | awk -F': ' '/[[:space:]]+Name[[:space:]]:/ { if ( $2 != "loginwindow" ) { print $2 }}'):staff "/Applications/Slack.app"
}

#update for if check
localSlackVersion=$(defaults read "/Applications/Slack.app/Contents/Info.plist" "CFBundleShortVersionString")
#Check if Slack is installed
if [ ! -d "/Applications/Slack.app" ]; then
	echo "=> Slack.app is not installed"
	install_slack
	#assimilate_ownership
	
	#tell user Slack is updated
        /Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper -windowType hud -windowPosition  ur -icon  /Applications/Slack.app/Contents/Resources/slack.icns -heading "Slack" -description "Slack $localSlackVersion has been Installed." -timeout 30 &


#If Slack version is not current install set permissions
elif [ "$currentSlackVersion" != "$localSlackVersion" ]; then
	install_slack
	#assimilate_ownership
	
	#tell user Slack is updated
        /Library/Application\ Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper -windowType hud -windowPosition  ur -icon  /Applications/Slack.app/Contents/Resources/slack.icns -heading "Slack" -description "Slack has been updated to $localSlackVersion" -timeout 30 &

	
#If Slack is installed and up to date just adjust permissions
elif [ -d "/Applications/Slack.app" ]; then
		if [ "$currentSlackVersion" = "$localSlackVersion" ]; then
			printf "Slack is already up-to-date. Version: %s" "$localSlackVersion"		
#assimilate_ownership			
			exit 0
	fi
fi
