#!/usr/bin/ruby
require 'csv'
require 'date'
require 'open-uri'

# Find countries in Webkit inspector:
# $x('//*[@data="ww"]/../*[@data]').filter(function(n) { var d = n.getAttribute('data'); return d == d.toUpperCase() }).map(function(n) { return "" + n.getAttribute('data') + ';' + n.textContent }).join("\n")

def uri
  date = Date.today - 7
  dstr = "%04d-%02d" % [date.year, date.cweek]
  base = 'http://gs.statcounter.com/chart.php?bar=1&statType_hidden=browser&region_hidden=%s&csv=1&'
  return base + ('granularity=weekly&fromWeekYear=%s&toWeekYear=%s' % [dstr, dstr])
end

Country = Struct.new(:code, :name)
def countries
  CSV.open('countries.csv', 'r', ';').map { |c, n| Country.new(c, n) }
end

def data_file(country)
  "data/#{country.name}.csv"
end

def download(country)
  csv = open(uri % country.code) { |u| u.read }
  open(data_file(country), 'w') { |f| f.write(csv) }
end

def download_many(countries)
  nthreads = 20
  jobs = Array.new(nthreads) { Array.new }
  countries.each_with_index { |c, i| jobs[i % nthreads] << c }
  
  threads = jobs.map do |j|
    Thread.new { j.each { |c| puts c.code; download(c) } }
  end
  threads.each { |t| t.join }
end

def download_all(del = nil)
  dir = Dir['data/*.csv']
  del ||= dir.empty? || (Time.now - File.mtime(Dir['data/*.csv'][0])) > 3 * 60 * 60 * 24
  
  needed = countries
  if !del
    needed = needed.select do |c|
      f = data_file(c)
      !File.exist?(f) || File.size(f) == 0
    end
  end
  
  download_many(needed)
  return !needed.empty?
end

def browsers(country)
  CSV.open(data_file(country), 'r').drop(1).inject({}) do |h, (k,v)|
    h[k] = v.to_f; h
  end
end

def browsers_all
  Hash[countries.map { |c| [c.name, browsers(c)] }]
end

def best_countries(name)
  browsers_all.map { |c,b| [c,b[name]] }.select { |c,b| b }.
      sort_by { |c,b| b }.each { |c,b| puts "%4.1f   %s" % [b, c] }
end

def rel_top(name)
  browsers_all.map do |c,b|
    if pct = b[name]
      npct = (b.values - [pct]).max
      next unless npct
      val = pct - npct
      str = "%+5.1f   %s" % [val, c]
      [val, str]
    end
  end.compact.sort.each { |k,s| puts s }
end

def total
  browsers = {}
  browsers_all.map do |c,bs|
    bs.map { |b,p| browsers[b] ||= 0.0; browsers[b] += p }
  end
  browsers.sort_by { |b,p| p }.each { |b,p| puts "%7.2f %s" % [p, b] }
end

if __FILE__ == $0
  browser = ARGV.shift
  download_all && 3.times { puts }
  
  rel_top(browser)
#  best_countries(browser)
#  total
end


