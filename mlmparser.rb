#!/usr/local/rvm/rubies/ruby-1.9.3-p194/bin/ruby

# useless the shebang in windows, but I'm use to it

# workflow
# validate file exist
# open file
# parse header
# parse ingredients
# parse preparation
# parse other headers
# gen xml

require 'rubygems'
require 'dbi'

class MyRecipe
  attr_accessor :title, :cat, :yield, :ingredients,:instructions,:mpat, :eor, :user_id, :format, :user_id
  def initialize(ofile = ARGV[0])
    @ofile = ofile
    @CarryCat = Array.new()
    @format = "hash"
    @catCount = 0
    @user_id = 1
    #@file
    self.mpat = "t|T|ea|c|x|lb|oz|tb|ts|lg|pn|sm|bn"
    self.eor = "^M{5}\s*$"
    self.ingredients = Array.new()
    self.instructions = String.new()
    @recipeCount = 0
    @date = Time.now.to_s.gsub(/ \+\d+$/,"")
    @finalDumpArr = Array.new()
    if @ofile.nil?
      p "use $0 <ml file>"
      raise ArgumentError.new("Invalid Argument")
    end
  end
  def init
    self.ingredients = Array.new()
    self.instructions = String.new()
  end
  def openf
    #@file = File.new(@ofile,"r")
    File.new(@ofile,"r")
  end
  def close
    @file.close
  end
  def catCreated?(thisCat)
    unless @CarryCat.include? thisCat
      @catCount += 1
      @CarryCat[@catCount] = thisCat
      return FALSE
    end
    return TRUE
  end
  def setDefaults
    #if self.title != ""
      #self.title.gsub!(/\s+/,"_")
      #self.title.gsub!(/'/,"")
    #end
  end
  def secureName(n)
    "r" + n.gsub(/\'|\s+|\,|\.|_|\(|\)|\*|\-/,"")
  end
  def checkFor(k,f)
    ftc = File.open(f,"rb")
    while (l = ftc.gets)
      if l.match(/^(\s*|#.*|\s+.*)$/)
        next
      end
      if l.match(k)
        return true
      end
    end
    ftc.close
    false
  end
  def dumpFile
    self.setDefaults
    dbh = DBI.connect("DBI:SQLite3:/home/matias/cookbook/db/development.sqlite3")
    dbh = DBI.connect("DBI:SQLite3:/home/matias/cookbook/db/production.sqlite3")
    #dbh = DBI.connect("DBI:SQLite2:/var/www/web2-work/MyCookBook-akelos/config/MyCookBook-akelos_dev-OifEg8Mb.sqlite")
    @recipeCount+=1
    if @format.match(/out1/)
      puts "Title: '#{ self.title }'"
      puts "Categories: '#{self.cat}'"
      puts "Yield: '#{self.yield}'"
      puts "--"
      puts "ingredinets: #{self.ingredients}"
      puts "--"
      puts "instructions: #{self.instructions}"
      puts "-------------"
      #mfile = File.new
    elsif @format.match(/fixture/)
      fr = File.open("recipes.yml","a+")
      fc = File.open("categories.yml","a+")
      fi = File.open("ingredients.yml","a+")
      fr.syswrite "#{self.secureName(self.title)}:\n"
      fr.syswrite "  title: #{self.title}\n"
      fr.syswrite "  yield: #{self.yield}\n"
      self.cat.each do |mycat|
        fc.syswrite "#{self.secureName(mycat)}:\n"
        fc.syswrite "  name: #{mycat}\n\n"
        fc.syswrite "  recipe: <%= ActiveRecord::Fixtures.identify(:#{self.secureName(self.title)}) %>\n"
      end
      self.ingredients.each do |mying|
        fi.syswrite "#{self.secureName(mying[:name])}:\n"
        fi.syswrite "  unit: #{mying[:unit]}\n"
        fi.syswrite "  amount: #{mying[:amount]}\n"
        fi.syswrite "  name: #{mying[:name]}\n"
        fi.syswrite "  recipe: <%= ActiveRecord::Fixtures.identify(:#{self.secureName(self.title)}) %>\n\n"
      end
      fr.syswrite "  instructions: |\n#{self.instructions}\n\n"
    elsif @format.match(/sqlite/)
      sth = dbh.prepare("insert into recipes (id,title,yield,instructions,created_at,updated_at) values (?,?,?,?,?,?)")
      sth.execute(@recipeCount, self.title, self.yield, self.instructions, @date, @date)
      self.cat.each do |mycat|
        sth = dbh.prepare("insert into categories (name,recipe_id,created_at,updated_at) values (?,?,?,?)")
        sth.execute(mycat,@recipeCount,@date,@date)
      end
      self.ingredients.each do |mying|
        sth = dbh.prepare("insert into ingredients (amount,unit,name,recipe_id,created_at,updated_at) values (?,?,?,?,?,?)")
        sth.execute(mying[:amount],mying[:unit],mying[:name],@recipeCount,@date,@date)
      end
    elsif @format.match(/sql/)
      puts "insert into recipes (id,title,yield,instructions,created_at,updated_at) values (\"#{@recipeCount}\", \"#{self.title}\", \"#{self.yield}\", \"#{self.instructions}\", \"#{@date}\", \"#{@date}\");"
      self.cat.each do |mycat|
        #puts "insert into categories (name,recipe_id,created_at,updated_at) values (\"#{mycat}\",\"#{@recipeCount}\",\"#{@date}\",\"#{@date}\");"
        # this is to habtm categories and recipes
        unless catCreated? mycat 
          puts "insert into categories (id,name,created_at,updated_at) values (\"#{@catCount}\",\"#{mycat}\",\"#{@date}\",\"#{@date}\");"
        end
        puts "insert into categories_recipes (recipe_id,category_id,created_at,updated_at) values (\"#{@recipeCount}\",\"#{@CarryCat.index mycat}\",\"#{@date}\",\"#{@date}\");"
      end
      self.ingredients.each do |mying|
        puts "insert into ingredients (amount,unit,name,recipe_id,created_at,updated_at) values (\"#{mying[:amount]}\",\"#{mying[:unit]}\",\"#{mying[:name]}\",\"#{@recipeCount}\",\"#{@date}\",\"#{@date}\");"
      end
    elsif @format.match(/hash/)
      cat_carry = self.cat.join(",").to_s.downcase
      ing_carry = self.ingredients
      print "a.push({ :title => \"#{self.title}\", :user_id => \"#{@user_id}\", :instructions => \"#{self.instructions.to_s}\", :yield => \"#{self.yield}\", :ingredients_attributes => #{ing_carry},:tag_list=>\"#{cat_carry}\"})"
      print "\n\n"
    elsif @format.match(/json/)
      cat_carry = self.cat.join(",").to_s.downcase
      ing_carry = self.ingredients
      @finalDumpArr.push({ :title => "#{self.title}", :user_id => "#{@user_id}", :instructions => "#{self.instructions.to_s}", :yield => "#{self.yield}", :ingredients_attributes => "#{ing_carry}",:tag_list=>"#{cat_carry}"})
    end
  end
  def finalDump
    require 'json'
    puts @finalDumpArr.to_json
  end
end


mr = MyRecipe.new()
mr.user_id = 1
mr.format = "json"
f = mr.openf
part = 0

#f.each{|line|
while (line = f.gets)
  #puts "#{$.} -> part #{part} -- #{ line}"
  if line.match(mr.eor)
    mr.dumpFile
    next
  end
  #if line=~/^\s*$/ && part != 3
  if line=~/^\s*$/
    #puts "#{$.} -> part #{part} -- #{ line}"
    if part != 3
      part+=1
    end
    next
  end
  if line=~/^MMMMM-----\s+.*Meal-Master/i
    part = 0
    mr.init
    next
  end
  if line=~/^MMMMM------*/
    if part >2
      part -= 1
    end
    next
  end

  if line=~/^\s*\:?\s*(\d+|\d+\/\d+)\s*(\w+\s*)?\w+.*\s*$/ && part == 3
    part = 2
  end

  if line=~/^\s*\d+\.\w+.*$/ && part == 2
    part = 3
  end

  if part == 1
    if line=~/^\s*Title\s*:\s*(.*)\s*$/i
      mr.title = $1
    elsif line=~/^\s*Categories\s*:\s*(.*)\s*$/i
      t = Array.new()
      $1.split(/\s*,\s*/).each{|x| t << x.gsub(/\.|\!|\*|\||\\/,"") }
      mr.cat = t
    elsif line=~/^\s*Yield\s*:\s*(.+)\s*$/i
      mr.yield = $1
    end
  # the ingredients part
  elsif part == 2
      line.gsub!(/^\s*:/,"")
      if line.match(/^\s*INGRED/i)
        next
      end
      #puts "#{$.} -> part #{part} -- #{ line}"
      t = Array.new()
      ins = Hash.new()
    #part+=1 if line=~/^\s*$/
    #puts $..to_s + " " + line
    lp = '^\s*(\d+\S*|\.\S+|\d+\/\d+)\s(' + mr.mpat + ')\s+(.+)\s*$'
    lp2 = '^\s*(\d+\s+\d\/\d+)\s(' + mr.mpat + ')\s+(.+)\s*$'
    if line.match(lp)
       ins[:amount] = $1
       ins[:unit] = $2.to_s.upcase
       ins[:name] = $3.to_s.downcase
    elsif line.match(lp2)
      ins[:amount] = $1
      ins[:unit] = $2.to_s.upcase
      ins[:name] = $3.to_s.downcase
    elsif line.match(/^\s+(\d+\S*|\.\S+)\s{2,}(\S+.*)\s*$/)
      ins[:amount] = $1
      ins[:name] = $2.to_s.downcase
      ins[:unit] = ""
    elsif line.match(/^\s*\-\s*(\S+.*)\s*$/)
      #mr.ingredients[-1][:name].gsub!(/\n/,"")
      mr.ingredients[-1][:name] += " " + $1.to_s.downcase
      next
    else
      ins[:name] = line.to_s.downcase
      ins[:name].gsub!(/^\s*/,"")
      ins[:name].gsub!(/\s*$/,"")
    end
    ins[:name].gsub!(/^-/,"")
    ins[:name].gsub!(/;|\(|\)/,"")
    ins[:name].gsub!(/(\d+)\"/,'\1 inch')
    t << ins
    mr.ingredients << ins
    #puts "part #{part}"
  # the last part
  elsif part == 3
    #puts "part #{part}"
    mr.instructions += "    " + line
  else
    #puts "Hell becoming"
    puts "parts in Hell are #{part}"
  end  
  
end

#mr.dumpFile
f.close
mr.finalDump

