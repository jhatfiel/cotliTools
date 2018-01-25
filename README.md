# cotliTools
A Collection of tools for Crusaders of the Lost Idols.

You will need your User ID and hash (easiest way to get these is by looking at the network log in Chrome's Dev Tools for any calls to post.php, then looking at the Request Headers).

The first time you specify your User ID and hash when running a script, it will be saved in a cache file and you won't have to specify it again.

## Ruby scripts
Requires a [Ruby interpreter](https://www.ruby-lang.org/en/) in your path.

### DE.rb
Manipulate legendary levels.  All materials are stored on the server.
  
       NOTE!!!!
  
   __***Your client will need to be refreshed to see changes.***__

       NOTE!!!!
       
Usage: `DE.rb` to see usage message

#### Example usages:

- First run to initialize your credential cache

   `DE.rb -u<userId> -h<hash>`
   
- Show your current legendary levels

   `DE.rb`
   
- Use cached defines file (when new gear is available, you should leave this out.  Note, your user details are never cached, they are loaded every time.)

   `DE.rb -c`
   
- Save your current legendary levels to the default file (`<server>.legendaries.yml.cache`)

   `DE.rb -S`
   
- Save your current legendary levels to a specified file

   `DE.rb -Snormal.legendaries.yml.cache`
   
- Disenchant all legendaries that higher than level 1, then re-create them at level 1

   `DE.rb -D`
   
- Attempt to restore all legendary items to the level listed in the default file

   `DE.rb -R`

- Attempt to restore all legendary items to the level listed in the specified file

   `DE.rb -Rnormal.legendaries.yml.cache`
   
- These can all be strung together to do something like: Save current levels, disenchant everything, and switch to a robot-specific formation

   `DE.rb -Snormal.legendaries.yml.cache -D -Rrobot.legendaries.yml.cache`
   

### playHistory.rb
Download your Play History and shows a summary of your runs.

Usage: `playHistory.rb` to see usage message

## Random batch scripts
Many of these tools require [jq](https://stedolan.github.io/jq/), [curl](https://curl.haxx.se/), and [toast](https://github.com/nels-o/toaster)

### watchForEvent.bat
Simply watches your userDetails to see if event_tokens are in your account yet.  Beats refreshing the game page over and over!

Usage: `watchForEvent.bat idlemaster <USERID> <HASH>`

## ToDo
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
