require 'json'
require 'yaml'
require 'optparse'
require 'open-uri'

SERVER_PREFIX='http://'
SERVER_SUFFIX='.djartsgames.ca/~idle/post.php?'
DEFINES_CACHE_SUFFIX='.defines.yml.cache'
LEGENDARIES_CACHE_SUFFIX='.legendaries.yml.cache'
CREDENTIALS_CACHE_SUFFIX='.credentials.yml.cache'

$options = {:server => 'idlemaster'}
optionParser = OptionParser.new do |opts|
  opts.banner = 'Usage: DE.rb [options]'

  opts.on('-v', '--[no-]verbose', 'Run verbosely') do |v|
    $options[:verbose] = v
  end

  opts.on('-uUSERID', '--userid=USERID', 'UserId, obtained from inspecting headers on post.php calls in browser client (REQUIRED)') do |v|
    $options[:userId] = v
  end  

  opts.on('-hHASH', '--hash=HASH', 'Your PRIVATE hash, obtained from inspecting headers on post.php calls in browser client (REQUIRED)') do |v|
    $options[:hash] = v
  end  

  opts.on('-sSERVER', '--server=SERVER', 'Server to use, defaults to idlemaster') do |s|
    $options[:server] = s
  end  

  opts.on('-D', '--disenchant', 'Disenchant all legendaries that are above level 1 and re-craft them at level 1') do |d|
    $options[:disenchant] = d
  end  

  opts.on('-S[FILE]', '--save=[FILE]', "Save legendary levels that are above level 1 out to <FILE> (defaults to <server>#{LEGENDARIES_CACHE_SUFFIX})") do |f|
    $options[:save] = f || $options[:server] + LEGENDARIES_CACHE_SUFFIX
  end  

  opts.on('-R[FILE]', '--restore=[FILE]', "Restore legendary levels from <FILE> (defaults to <server>#{LEGENDARIES_CACHE_SUFFIX})") do |f|
    $options[:restore] = f || $options[:server] + LEGENDARIES_CACHE_SUFFIX
  end  

  opts.on('-sSERVER', '--server=SERVER', 'Server to use, defaults to idlemaster') do |s|
    $options[:server] = s
  end  

  opts.on('-c', '--cache', 'Use only cached data, don\'t update from the server') do |c|
    $options[:cache] = c
  end

  opts.on('-?', '--help', 'This help message') do
    puts opts
    exit
  end  
end
optionParser.parse!
puts $options[:userId]
puts $options[:save]
exit

def saveCredentials(server, userId, hash)
  fn = server + CREDENTIALS_CACHE_SUFFIX
  File.write(fn, {:userId => userId, :hash => hash}.to_yaml)
end

def loadCredentials(server)
  userId = $options[:userId]
  hash = $options[:hash]

  if !userId || !hash
    fn = server + CREDENTIALS_CACHE_SUFFIX
    unless File.file?(fn)
      puts "No credentials specified and #{fn} not found"
      exit
    end
    credentials = YAML.load_file(fn)
    userId = credentials[:userId]
    hash = credentials[:hash]
  else
    saveCredentials(server, userId, hash)
  end

  return [userId, hash]
end

def getDefines(server)
  defines = []
  fn = server + DEFINES_CACHE_SUFFIX

  ## get defines appropriately based on options
  if $options[:cache] and File.file?(fn)
    ## Read from cache
    print 'Loading defines from cache...'
    defines = YAML.load_file(fn)
  else 
    ## Read from server
    print 'Loading defines from server...'

    url = SERVER_PREFIX + server + SERVER_SUFFIX + 'call=getDefinitions'

    defines = JSON.parse(open(url) { |f| f.read })

    ## Write cache
    print 'Writing cache...'
    File.write(fn, defines.to_yaml)
  end

  puts 'Done'

  return defines
end

def callGetUserDetails(server, userId, hash)
  ## Read from server
  userDetails = []

  print 'Loading userDetails from server...'

  url = SERVER_PREFIX + server + SERVER_SUFFIX + "call=getUserDetails&instance_key=0&user_id=#{userId}&hash=#{hash}"

  userDetails = JSON.parse(open(url) { |f| f.read })

  puts 'Done'

  if userDetails['failure_reason']
    puts "Eror loading user details:"
    puts "URL: #{url}"
    puts "ERROR: #{userDetails['failure_reason']}"
    exit
  end

  return userDetails
end

def getLegendaryItems(defines, userDetails)
  ## Pull defines.loot_defines where rarity = 5
  heroArr = []
  lootArr = []
  legendaryItems = {}
  defines['hero_defines'].each do |hero|
    heroArr[hero['id']] = hero
  end
  defines['loot_defines'].each do |loot|
    lootArr[loot['id']] = loot if loot['rarity'] == 5
  end
  ## Pull userDetails.details.loot where loot_id had rarity = 5
  userDetails['details']['loot'].each do |loot|
    id = loot['loot_id']
    if lootArr[id]
      lootDef = lootArr[id]
      heroDef = heroArr[lootDef['hero_id']]
      legendaryItems[id] = {
          :id => id,
          :crusader => heroDef['name'],
          :item => lootDef['name'],
          :level => loot['count']
      }
    end
  end

  ## Return hash (with crusader name/loot name/level)
  return legendaryItems
end

def getInstanceId(userDetails)
  ## Pull out and return .details.instance_id
  return userDetails['details']['instance_id']
end

def callDisenchantLegendary(server, userId, hash, instanceId, item)
  ## Call server, ensure .success === 'true', exit otherwise
  ## ?user_id=%USER%&hash=%HASH%&instance_id=%INSTANCE%&call=disenchantLegendary&loot_id=1139
  url = SERVER_PREFIX + server + SERVER_SUFFIX + "call=disenchantLegendary&instance_id=#{instanceId}&user_id=#{userId}&hash=#{hash}&loot_id=#{item[:id]}"
  print "Disenchanting #{item[:crusader]}'s #{item[:item]} level #{item[:level]}..."
  response = JSON.parse(open(url) { |f| f.read })
  if response['success'] != true || response['okay'] != true
    puts "Error Disenchanting Legendary!"
    puts "ITEM: #{item}"
    puts "URL: #{url}"
    puts "RESPONSE: #{response}"
    exit
  end
  puts "#{response['crafting_materials']['1']} common mats"
end

def callCraftLegendary(server, userId, hash, instanceId, item, upgrade)
  ## Call server, ensure .success === 'true', exit otherwise
  ## ?user_id=%USER%&hash=%HASH%&instance_id=%INSTANCE%&call=craftItem&loot_id=1139
  url = SERVER_PREFIX + server + SERVER_SUFFIX + "call=craftItem&instance_id=#{instanceId}&user_id=#{userId}&hash=#{hash}&loot_id=#{item[:id]}"
  url += "&crafting_material_id=1" if upgrade
  print "#{(upgrade ? 'Upgrading' : 'Crafting')} #{item[:crusader]}'s #{item[:item]}..."
  response = JSON.parse(open(url) { |f| f.read })
  if response['success'] != true || response['okay'] != true
    puts "Error Crafting Legendary!"
    puts "ITEM: #{item}"
    puts "URL: #{url}"
    puts "RESPONSE: #{response}"
    exit
  end
  puts "#{response['crafting_materials']['1']} common mats"
end

def showLegendaryItems(legendaryItems)
  puts "Current Legendary Items above level 1"
  legendaryItems.each do |id, item|
    puts "#{item[:crusader]}'s #{item[:item]}: #{item[:level]} (id=#{item[:id]})" if item[:level] > 1
  end
end

def disenchantAll(server, userId, hash, instanceId, legendaryItems)
  legendaryItems.each do |id, item|
    if item[:level] > 1
      callDisenchantLegendary(server, userId, hash, instanceId, item)
      callCraftLegendary(server, userId, hash, instanceId, item, false)
      item[:level] = 1
    end
  end
end

def saveLegendaryLevels(legendaryItems)
  puts "Saving legendary levels to #{$options[:save]}"
  File.write($options[:save], legendaryItems.to_yaml)
end

def restoreLegendaryLevels(server, userId, hash, instanceId, legendaryItems)
  fn = $options[:restore]
  puts "Restoring legendary levels from #{fn}"

  if !File.file?(fn)
    puts "ERROR: Could not find #{fn}"
    exit
  end

  newLegendaryItems = YAML.load_file(fn)

  ## Loop through the newLegendaryItems
  newLegendaryItems.each do |id, item|
    if item[:level] > 1
      ## Compare the level desired with the current level
      if legendaryItems[id] 
        if legendaryItems[id][:level] < item[:level]
          ## call craftItem enough times to upgrade it
          (item[:level] - legendaryItems[id][:level]).times do
            callCraftLegendary(server, userId, hash, instanceId, item, true)
          end
        end
      else
        puts "Cowardly refusing to craft #{item[:crusader]}'s #{item[:item]}.  Please craft the epic to legendary in-game first."
      end
    end
  end
end

## Main program start
STDOUT.sync = true

## load options for ease of access
server = $options[:server]
(userId, hash) = loadCredentials(server)

defines = getDefines(server)
userDetails = callGetUserDetails(server, userId, hash)

legendaryItems = getLegendaryItems(defines, userDetails)

if $options[:verbose] ||
  (!$options[:save] && !$options[:restore] && !$options[:disenchant])
  showLegendaryItems(legendaryItems)
end

if $options[:save]
  saveLegendaryLevels(legendaryItems)
end

instanceId = getInstanceId(userDetails)

if $options[:disenchant]
  disenchantAll(server, userId, hash, instanceId, legendaryItems)
end

if $options[:restore]
  restoreLegendaryLevels(server, userId, hash, instanceId, legendaryItems)
end

