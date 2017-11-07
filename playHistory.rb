require 'json'
require 'yaml'
require 'optparse'
require 'open-uri'

$options = {:max => 10, :action => 'LOG'}
optionParser = OptionParser.new do |opts|
  opts.banner = 'Usage: playHistory.rb [options]'

  opts.on('-v', '--[no-]verbose', 'Run verbosely') do |v|
    $options[:verbose] = v
  end  

  opts.on('-uUSERID', '--userid=USERID', 'UserId, obtained from inspecting headers on post.php calls in browser client (REQUIRED)') do |v|
    $options[:userId] = v
  end  

  opts.on('-hHASH', '--hash=HASH', 'Hash, obtained from inspecting headers on post.php calls in browser client (REQUIRED)') do |v|
    $options[:hash] = v
  end  

  opts.on('-c', '--cache', 'Use only cached data, don\'t update from the server') do |v|
    $options[:cache] = v
  end

  opts.on('-d', '--deleteCache', 'Delete the cache and exits - only use if you\'re tired of seeing older information or something is broken') do |v|
    $options[:delete] = v
  end

  opts.on('-aACTION', '--action=ACTION', "Action to perform.  Choose from LOG, CHEST (default: #{$options[:action]})") do |v|
    $options[:action] = v
  end

  opts.on('-tTYPE', '--type=TYPE', 'Type used as argument to --action command') do |v|
    $options[:type] = v
  end

  opts.on('-mMAX', '--max=MAX', "Maximium number of pages to retrieve (default: #{$options[:max]})") do |v|
    $options[:max] = Integer(v)
  end

  opts.on('-?', '--help', 'This help message') do
    puts opts
    exit
  end  
end
optionParser.parse!

LOOT = {
  1743 => 'C Sword',
  1744 => 'U Sword',
  1745 => 'R Sword',
  1746 => 'E Sword',
  1748 => 'C Star',
  1749 => 'U Star',
  1750 => 'R Star',
  1751 => 'E Star',
  1753 => 'C Mask',
  1754 => 'U Mask',
  1755 => 'R Mask',
  1756 => 'E Mask'
}

## function, global and constant definition
RESET_ENTRY='1'
CHEST_ENTRY='0'

def loadCache(userId)
  history = []
  fn = "playHistory.#{userId}.cache"
  if File.file?(fn)
    print 'Reading cache...'
    history = YAML.load_file(fn)
    puts 'Done'
  end
  return history
end

def writeCache(userId, history)
  fn = "playHistory.#{userId}.cache"
  print 'Writing cache...'
  File.write(fn, history.to_yaml)
  puts 'Done'
end

def loadPlayHistory(userId, hash, pages, history)
  puts 'Creating unique cache of history_date' if $options[:verbose]
  existingIds = {}
  history.each do |entry|
    existingIds[entry['history_date']] = 1
  end

  print 'Loading data from the server...'
  print "\n" if $options[:verbose]
  baseUrl = "http://idlemaster.djartsgames.ca/~idle/post.php?call=getPlayHistory&instance=0&user_id=#{userId}&hash=#{hash}&page="

  # load data
  new = []
  newIds = {}
  for i in 1..pages
    print "Loading page #{i} from #{baseUrl}#{i}..." if $options[:verbose]
    h = JSON.parse(open(baseUrl + i.to_s) { |f| f.read })
    done = false
    thisNew = []
    h['entries'].each do |entry|
      historyId = entry['history_date']
      if existingIds[historyId]
        done = true
        break
      else
        if newIds[historyId].nil?
          thisNew.push(entry)
          newIds[historyId] = 1
        end
      end
    end
    print '.' if !$options[:verbose]
    print "...#{thisNew.size}\n" if $options[:verbose]
    new += thisNew
    if done || thisNew.size == 0
      puts '' if !$options[:verbose]
      puts 'Found overlap with cached data...' if done
      break
    end
  end

  puts 'Finished loading from server'

  history = new + history

  return history
end

def loadHistory(userId, hash, pages)
  history = loadCache(userId)
  if !$options[:cache]
    history = loadPlayHistory(userId, hash, pages, history)
    writeCache(userId, history)
  end
  history = processPlayHistory(history)
  return history
end

def deleteCache(userId)
  fn = "playHistory.#{userId}.cache"
  if File.file?(fn)
    File.delete(fn)
  end
end

def processPlayHistory(history)
  print 'Processing play history...'
  # store the most recent reset so once we hit the next one we can output stats about this one
  lastReset = nil
  fakeReset = nil

  history.each do |entry|
    case entry['type']
      when RESET_ENTRY
        resetSummary(lastReset, true) if $options[:verbose]
        lastReset = entry
        nextBoss = Integer(entry['info']['highest_area_unlocked'] || entry['info']['current_area'])
        lastReset[:nextBossArea] = nextBoss/5*5
        numBosses = (nextBoss - 95)/5
        lastReset[:numBosses] = (numBosses>0) ? numBosses : 0
        lastReset[:numChestBosses] = nextBoss/5
        lastReset[:numBossesWithBI] = 0
        lastReset[:numBossesWithChests] = 0
        lastReset[:numBossesWithRChests] = 0
        lastReset[:bonusBossIdols] = 0
      when CHEST_ENTRY
        if entry['info']['action'] === 'add_normal'
          bossArea = Integer(entry['info']['chest_area_sent'])
          if lastReset == nil
            numBosses = (bossArea-95)/5
            numBosses = (numBosses>0) ? numBosses : 0
            lastReset = {
              'type' => RESET_ENTRY,
              'history_date' => Time.new.strftime('%Y-%m-%d %H:%M:%S'),
              'info' => {
                'highest_area_unlocked' => bossArea,
                'num_previous_resets' => 'CURRENT'
              },
              :current => true,
              :numBosses => numBosses,
              :numChestBosses => bossArea/5,
              :numBossesWithBI => 0,
              :numBossesWithChests => 0,
              :numBossesWithRChests => 0,
              :nextBossArea => bossArea,
              :bonusBossIdols => 0
            }
            fakeReset = lastReset
          end

          bbiGained = entry['info']['bonus_boss_idols']['gained']
          if bbiGained > 0
            lastReset[:numBossesWithBI] += 1
            bbiAfter = entry['info']['bonus_boss_idols']['after']
            skipped = (lastReset[:nextBossArea]-bossArea)/5
            lastReset[:nextBossArea] = bossArea - 5
            lastReset[:bonusBossIdols] += bbiGained
            puts "#{entry['play_history_id']} #{entry['history_date']} Got #{bbiGained} (#{bbiAfter}) #{lastReset[:bonusBossIdols]} bonus boss idols at area #{bossArea}" if $options[:verbose]
          end

          normalGained = entry['info']['normal_chests']['gained']
          rareGained = entry['info']['rare_chests']['gained']
          if normalGained > 0
            lastReset[:numBossesWithChests] += 1
          end
          if rareGained > 0
            lastReset[:numBossesWithRChests] += 1
          end
        end
    end
  end
  resetSummary(lastReset, false) if $options[:verbose]
  history.unshift(fakeReset) if fakeReset
  puts 'Done'
  return history
end

def showResetStats(history)
  lastReset = nil
  history.reverse.each do |entry|
    case entry['type']
      when RESET_ENTRY
        if lastReset != nil
          resetSummary(lastReset, true)
        end
        lastReset = entry
    end
  end
  resetSummary(lastReset, false)
end

def resetSummary(r, complete)
  resetId = "%7s" % r['info']['num_previous_resets']
  date = r['history_date'][5..-1]
  highestArea = r['info']['highest_area_unlocked']
  runTime = r['info']['play_time'] || 0
  runTime = (Integer(runTime)*10/60/60).to_f/10
  percentBonusDrops = 0
  percentChestDrops = 0
  numberChestDrops = r[:numBossesWithChests]
  numberRareChestDrops = r[:numBossesWithRChests]
  if (r[:numBosses] > 0)
    percentBonusDrops = (r[:numBossesWithBI]*10000/r[:numBosses] + 0.0)/100
  end
  if (r[:numChestBosses] > 0)
    percentChestDrops = ((numberChestDrops+numberRareChestDrops)*10000/r[:numChestBosses] + 0.0)/100
  end

  bonusBossIdols = r[:bonusBossIdols];

  if resetId === 'CURRENT'
    puts "##{resetId} #{date} a#{highestArea} BI: #{bonusBossIdols} (#{percentBonusDrops}%) #{(complete==true)?'':'(incomplete)'}"
  else
    idolsGained = r['info']['idols']['gained']
    totalIdols = Integer(r['info']['idols']['spent']) + Integer(r['info']['idols']['after'])

    puts "##{resetId} #{date} a#{highestArea} (#{runTime}h) I: #{idolsGained} (#{totalIdols}) BI: #{bonusBossIdols} (#{percentBonusDrops}%) C: #{numberChestDrops}/#{numberRareChestDrops} (#{percentChestDrops}%) #{(complete==true)?'':'(incomplete)'}"
  end
end

def showChestOpenings(history, type)
  history.reverse.each do |entry|
    info = entry['info']
    if info['action'] === 'use_generic_chest' && info['chest_type_id'] == type
      num = Integer(info['chests']['used'])
      for i in 0..num-1
        i1 = info['loot'][i*5+0]['disenchant_item_id'] || info['loot'][i*5+0]['add_item_id']
        i2 = info['loot'][i*5+1]['disenchant_item_id'] || info['loot'][i*5+1]['add_item_id']
        puts "#{LOOT[Integer(i1)]}"
        puts "#{LOOT[Integer(i2)]}"
      end
    end
  end
end

## Handle options and usage help message
if $options[:userId] && $options[:delete]
  deleteCache($options[:userId])
  puts "Cache for user #{$options[:userId]} deleted!"
  exit
end
if $options[:userId].nil? || $options[:hash].nil?
  optionParser.parse %w[-?]
  exit
end

## Main program start
STDOUT.sync = true

history = loadHistory($options[:userId], $options[:hash], $options[:max])

case $options[:action] 
  when 'LOG'
    showResetStats(history)
  when 'CHEST'
    if $options[:type].nil?
      puts 'Please specify chest type'
      exit
    end
    showChestOpenings(history, $options[:type])
end
