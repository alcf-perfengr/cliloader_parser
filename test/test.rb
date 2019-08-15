[ '../lib', 'lib' ].each { |d| $:.unshift(d) if File::directory?(d) }
require 'minitest/autorun'
require 'cliloader'

require_relative 'parser'
require_relative 'files'
require_relative 'extractor'
require_relative 'state'
