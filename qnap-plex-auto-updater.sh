#!/bin/bash

# enable or disable debug output
debug=$false

# get current directory
scriptDir=$(dirname "$0")
# get system architecture
architecture=$(uname -m)

# select build based on architecture
case $architecture in
  x86_64)
    build="linux-x86_64"
    ;;
  aarch64)
    build="linux-aarch64"
    ;;
  armv7l)
    # check if system supports neon instructions
    if cat /proc/cpuinfo | grep -q "neon"; then
      build="linux-armv7neon"
    else
      build="linux-armv7hf"
    fi
    ;;
  *)
    echo "Unsupported architecture: $architecture"
    exit 1
    ;;
esac

# get current downloaded plex server version
# currentVersion=$(cat "$scriptDir/current")
if [ -f "/share/PlexData/Plex Media Server/Logs/Plex Media Server.log" ]; then
    currentVerion=$(grep -oP "Plex Media Server v\K[^\s]+" "/share/PlexData/Plex Media Server/Logs/Plex Media Server.log" | tail -1)
    echo "Installed version: $currentVerion"
else
    echo "No log file found. Assuming latest version needs to be installed."
    last=""
fi
if [[ $debug ]]
then
	echo "Installed: $currentVersion"
fi 

# get plex token from preferences and build url
plex_token=$(cat "/share/PlexData/Plex Media Server/Preferences.xml" | grep -oE 'PlexOnlineToken="[^"]+"' | sed -E 's/PlexOnlineToken="([^"]+)"/\1/')
plex_url="https://plex.tv/api/downloads/5.json?channel=plexpass&X-Plex-Token=$plex_token"
if [[ $debug ]]
then
	echo "Plex URL: $plex_url"
fi

# get latest data from plex
latestVersion=$(echo $(curl -s $plex_url) | jq ".nas.QNAP | .version" | tr -d '"')
latestQPKG=$(echo $(curl -s $plex_url) | jq ".nas.QNAP.releases[] | select(.build==\"$build\") | .url" | tr -d '"')
if [[ $debug ]]
then
	echo "Latest Version: $latestVersion"
	echo "QPKG:           $latestQPKG"
fi

# compare currentVersion and plex version
if [[ $currentVersion != $latestVersion ]]
then
    echo "New Plex Media Server Version detected"
	echo "  Latest:  $latestVersion"
	echo "  Current: $currentVersion"
	echo ""
    
	echo "Downloading from: $latestQPKG"
    curl "$latestQPKG" -s -o "$scriptDir/plex.qpkg"
	
	echo "Installing Version $latestVersion"
    sh "$scriptDir/plex.qpkg"
    
	echo "Install done. Removing downloaded File"
    rm "$scriptDir/plex.qpkg"
    
	echo "Updating Version DB to $latestVersion"
    echo $latestVersion > $scriptDir/current
	
	echo ""
    echo "Plex Media Server Update done."
else
    echo "No new Plex Media Server Version detected"
    echo "  Latest:  $latestVersion"
	echo "  Current: $currentVersion"
fi
