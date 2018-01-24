require 'json'
require 'yaml'
require 'optparse'
require 'open-uri'

SERVER_PREFIX='http://'
SERVER_SUFFIX='.djartsgames.ca/~idle/post.php?'
DEFINES_CACHE_SUFFIX='.defines.cache.json'

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

  opts.on('-c', '--cache', 'Use only cached data, don\'t update from the server') do |v|
    $options[:cache] = v
  end

  opts.on('-?', '--help', 'This help message') do
    puts opts
    exit
  end  
end
optionParser.parse!

def getDefines(server)
  defines = []
  fn = server + DEFINES_CACHE_SUFFIX

  ## get defines appropriately based on options
  if $options[:cache] and File.file?(fn)
    ## Read from cache
    print 'Loading defines from cache...' if $options[:verbose]
    defines = YAML.load_file(fn)

    puts 'Done' if $options[:verbose]
  else 
    ## Read from server
    print 'Loading defines from server...' if $options[:verbose]

    url = SERVER_PREFIX + server + SERVER_SUFFIX + 'call=getDefinitions'

    defines = JSON.parse(open(url) { |f| f.read })

    ## Write cache
    print 'Writing cache...' if $options[:verbose]
    File.write(fn, defines.to_yaml)

    puts 'Done' if $options[:verbose]
  end

  return defines
end

def callGetUserDetails(server, userId, hash)
  ## Read from server
  userDetails = []

  print 'Loading userDetails from server...' if $options[:verbose]

  url = SERVER_PREFIX + server + SERVER_SUFFIX + "call=getUserDetails&instance_key=0&user_id=#{userId}&hash=#{hash}"

  userDetails = JSON.parse(open(url) { |f| f.read })

  puts 'Done' if $options[:verbose]

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
  legendaryItems = []
  defines['hero_defines'].each do |hero|
    heroArr[hero['id']] = hero
  end
  defines['loot_defines'].each do |loot|
    lootArr[loot['id']] = loot if loot['rarity'] == 5
  end
  ## Pull userDetails.details.loot where loot_id had rarity = 5 and count > 1
  userDetails['details']['loot'].each do |loot|
    if loot['count'] > 1 and lootArr[loot['loot_id']]
      lootDef = lootArr[loot['loot_id']]
      heroDef = heroArr[lootDef['hero_id']]
      legendaryItems.push({
        "id" => loot['loot_id'],
        "crusader" => heroDef['name'],
        "item" => lootDef['name'],
        "level" => loot['count']
      })
    end
  end

  ## Return array (with crusader name/loot name/level)
  return legendaryItems
end

def getInstanceId(userDetails)
  ## Pull out and return .details.instance_id
  return userDetails['details']['instance_id']
end

def callDisenchantLegendary(server, userId, hash, instanceId, item)
  ## Call server, ensure .success === 'true', exit otherwise
  ## ?user_id=%USER%&hash=%HASH%&instance_id=%INSTANCE%&call=disenchantLegendary&loot_id=1139
  url = SERVER_PREFIX + server + SERVER_SUFFIX + "call=disenchantLegendary&instance_id=#{instanceId}&user_id=#{userId}&hash=#{hash}&loot_id=#{item['id']}"
  puts "Disenchanting #{item['crusader']}'s #{item['item']} level #{item['level']}"
  response = JSON.parse(open(url) { |f| f.read })
  if response['success'] != true
    puts "Error Disenchanting Legendary!"
    puts item
    puts response
    exit
  end
end

def callCraftLegendary(server, userId, hash, instanceId, item)
  ## Call server, ensure .success === 'true', exit otherwise
  ## ?user_id=%USER%&hash=%HASH%&instance_id=%INSTANCE%&call=craftItem&loot_id=1139
  url = SERVER_PREFIX + server + SERVER_SUFFIX + "call=craftItem&instance_id=#{instanceId}&user_id=#{userId}&hash=#{hash}&loot_id=#{item['id']}"
  puts "Crafting #{item['crusader']}'s #{item['item']}"
  response = JSON.parse(open(url) { |f| f.read })
  if response['success'] != true
    puts "Error Crafting Legendary!"
    puts item
    puts response
    exit
  end
end

def showLegendaryItems(legendaryItems)
  puts legendaryItems
end

def disenchantAll(server, userId, hash, instanceId, legendaryItems)
  legendaryItems.each do |item|
    callDisenchantLegendary(server, userId, hash, instanceId, item)
    callCraftLegendary(server, userId, hash, instanceId, item)
  end
end

## Main program start
STDOUT.sync = true

## load options for ease of access
server = $options[:server]
userId = $options[:userId]
hash = $options[:hash]

defines = getDefines(server)
userDetails = callGetUserDetails(server, userId, hash)

legendaryItems = getLegendaryItems(defines, userDetails)

if $options[:verbose]
  showLegendaryItems(legendaryItems)
end

instanceId = getInstanceId(userDetails)

disenchantAll(server, userId, hash, instanceId, legendaryItems)

