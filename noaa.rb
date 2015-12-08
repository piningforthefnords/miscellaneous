#!/usr/bin/env ruby
# encoding: utf-8
#
# NOAA to plotly
#

require 'pp'
require 'curb'
require 'json'
require 'zlib'
require 'plotly'
require 'stringio'
require 'optparse'

baseurl = 'http://www.ndbc.noaa.gov/data/historical/stdmet'
suffix = '.txt.gz'
apiuser = 'PUT USER HERE'
apikey = 'PUT API KEY HERE'

def fetch_file(uri)
  http = Curl.get(uri)
  http.body_str
end

def gzread(cmpr)
    zstream = Zlib::Inflate.new(16+Zlib::MAX_WBITS)
    buf = zstream.inflate(cmpr)
    zstream.finish
    zstream.close
    buf
end

def c_to_f(celtemp)
  (((9*Float(celtemp))/5) + 32).round(2)
end

def f_to_c(fahrentemp)
  (5*(Float(fahrentemp) - 32))/9.round(2) 
end

# s: station, b: begin year, e: end year
# Defaults to Mobile Bay since 2010 until last year
params = ARGV.getopts('s:b:e:')
station = params['s'] ||= 42012
s_year = params['b'] ||= 2010
e_year = params['e'] ||= (Time.now.year - 1)

processme = String.new
span = (s_year..e_year).to_a

span.each do |yr|
  begin
    uri = "#{baseurl}/#{station}h#{yr}#{suffix}"
    processme << gzread(fetch_file(uri))
  rescue => err
    warn "Could not process #{uri}. Error: \n#{err}\n"
  end
end

output = Hash.new

processme.split("\n").each do |ln|
  arr = ln.split
  next if arr[0] =~ /^#/
  wtmp = c_to_f(arr[14].to_f)
  next unless wtmp.kind_of?(Float)
  next if wtmp > 100.0 || wtmp < 32.0
  date = "#{arr[0]}-#{arr[1]}-#{arr[2]}"
  output[date] = wtmp unless output.key?(date)
end

plotly = PlotLy.new(apiuser, apikey)
data = Hash.new
data['x'] = output.keys
data['y'] = output.values

args = {
  filename: "noaa_historical_#{station}",
  fileopt: 'overwrite',
  style: { type: 'scatter' },
  layout: {
    title: "NOAA #{station} Historical Water Temperature"
  },
  world_readable: true
}

plotly.plot(data, args) do |response|
  puts response['url']
end

__END__
