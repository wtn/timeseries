require 'date'

module Timeseries
	class DataPoint
		attr_accessor :date , :value

		def initialize date = DateTime.new , value = 0
			raise ArgumentError , "Must use ruby DateTime format for DataPoint dates" unless date.class == DateTime
			@date = date
			@value = value
		end
	end
end