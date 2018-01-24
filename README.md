# cotliTools
A Collection of tools for Crusaders of the Lost Idols

You will need your User ID and hash (easiest way to get these is by looking at the network log in Chrome's Dev Tools for any calls to post.php, then looking at the Request Headers)

## Ruby scripts
Requires a [Ruby interpreter](https://www.ruby-lang.org/en/) in your path.

### playHistory.rb
Download your Play History and shows a summary of your runs - 
Usage: `playHistory.rb` to see usage message

### DE.rb
Disenchant all legendaries that are higher than level 1 and recreate them.  All materials are stored on the server.  Your client will need to be refreshed to see changes.
Usage: `DE.rb` to see usage message

## Random batch scripts
Many of these tools require [jq](https://stedolan.github.io/jq/), [curl](https://curl.haxx.se/), and [toast](https://github.com/nels-o/toaster)

### watchForEvent.bat
Simply watches your userDetails to see if event_tokens are in your account yet.  Beats refreshing the game page over and over!

Usage: `watchForEvent.bat idlemaster <USERID> <HASH>`

## ToDo
### enchant.rb
Enchant legendaries according to `legendaries.txt`.  Your client will need to be refreshed to see changes.
Usage: `DE.rb` to see usage message

- Remove hard-coding of paths for tools
- playHistory.rb
  - specify server
  - store user/hash
  - if only 1 user/hash stored, use it by default
  - if only user is specified, lookup hash
  - load server defines for uses in other places
  - load cache and update from server if desired, then provide UI for doing other things like
    - view most recent complete time for missions (by category or mission type)
    - view details on a run - boss idols, chest drops, areas per hour through every 100 areas or so
- new program - missionRunner.rb
  - runs in background
  - grabs userDetails and pulls the instance_id
  - starts available_missions - low EP crusaders for EP missions, high EP crusaders for all others
  - completes active_missions
  - config
    - userid/hash
    - autoRefresh - flag that determines if the instance_id should be refreshed once it is determined to be invalid (because you have logged in somewhere else)
    - excludeFormationSave - don't send crusaders that are in any saved formation slot for World's Wake
    - excludeMission - list of missions to exclude (like Up To Speed) (maybe support whole categories of missions?)
    - excludeCrusaders - list of crusaders to never send on missions
    - imperfectMissions - allow < 100% missions to be started 
