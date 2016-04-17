#!/usr/local/rvm/rubies/ruby-2.1.1/bin/ruby
# encoding: utf-8


####
#
# A site with file definitions:
#     * http://www.wedesoft.de/anymeal-api/mealmaster.html
#
#
####


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
    self.mpat = "t|T|ea|c|x|lb|oz|tb|ts|lg|pn|sm|bn|cn"
    self.eor = /MMMMM\s*$/ # "^M{5}\s*$"
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
    File.new(@ofile,"rb")
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
      dbh = DBI.connect("DBI:SQLite3:/home/matias/cookbook/db/development.sqlite3")
      #dbh = DBI.connect("DBI:SQLite3:/home/matias/cookbook/db/production.sqlite3")
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
mr.format = "hash"
f = mr.openf
part = 0

while (line = f.gets)
  if line.match(mr.eor)
    mr.dumpFile
    next
  end
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
      mr.title = $1.strip
    elsif line=~/^\s*Categories\s*:\s*(.*)\s*$/i
      t = Array.new()
      $1.split(/\s*,\s*/).each{|x| t << x.gsub(/\.|\!|\*|\||\\/,"").strip }
      mr.cat = t
    elsif line=~/^\s*Yield\s*:\s*(.+)\s*$/i
      mr.yield = $1.strip
    end
  # the ingredients part
  elsif part == 2
      line.gsub!(/^\s*:/,"")
      if line.match(/^\s*INGRED/i)
        next
      end
      if mr.ingredients[-1].nil? && line.match(/^\s+-/)
        p "debug:::-> #{line}"
        next
      end
      #puts "#{$.} -> part #{part} -- #{ line}"
      t = Array.new()
      ins = Hash.new()
    lp = '^\s*(\d+\S*|\.\S+|\d+\/\d+)\s(' + mr.mpat + ')\s+(.+)\s*$'
    lp2 = '^\s*(\d+\s+\d+\/\d+)\s(' + mr.mpat + ')\s+(.+)\s*$'
    if line.match(lp)
       ins[:amount] = $1.strip
       ins[:unit] = $2.to_s.strip.upcase
       ins[:name] = $3.to_s.strip.downcase
    elsif line.match(lp2)
      ins[:amount] = $1.strip
      ins[:unit] = $2.to_s.strip.upcase
      ins[:name] = $3.to_s.strip.downcase
    elsif line.match(/^\s+(\d+\S*|\.\S+)\s{2,}(\S+.*)\s*$/)
      ins[:amount] = $1.strip
      ins[:name] = $2.to_s.strip.downcase
      ins[:unit] = ""
    elsif line.match(/^\s*\-\s*(\S+.*)\s*$/)
      p mr.ingredients[-1].class
      mr.ingredients[-1][:name] += " " + $1.to_s.strip.downcase
      next
    else
      ins[:name] = line.to_s.strip.downcase
    end
    ins[:name].gsub!(/^-/,"")
    ins[:name].gsub!(/;|\(|\)/,"")
    ins[:name].gsub!(/(\d+)\"/,'\1 inch')
    t << ins
    mr.ingredients << ins
  # the last part
  elsif part == 3
    mr.instructions += line.strip + "\n"
  else
    # this means that something went really wrong
    puts "parts in Hell are #{part}"
  end  
  
end

f.close

