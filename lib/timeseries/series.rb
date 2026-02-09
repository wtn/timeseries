require 'date'
require 'active_support'
require 'active_support/core_ext/date_time'
require 'timeseries/data_point'
module Timeseries
	# Series - a time-ordered array of values
	# 	equations from here: http://stockcharts.com/school/doku.php?id=chart_school:technical_indicators:moving_averages
	class Series < Array
		def initialize *args
			super
			each { |item| raise ArgumentError , 'Invalid item added to Series, must be Timeseries::DataPoint' unless item.class == Timeseries::DataPoint }
		end

		# Returns
		def sum_range offset = 0 , time_period = 7
			self[offset,time_period].inject(0) { |total,dp| total.to_f + dp.value.to_f }
		end

		def sum
			inject(0) { |total,dp| total.to_f + dp.value.to_f }
		end

		# Generates time series where the DataPoint object values are moving averages
		#
		# @return [Timeseries::Series] moving average series
		def moving_average time_period = 7
			moving_averages = zero_empty_dates.each_with_index.map do |c,i|
				dp = DataPoint.new
				dp.value = single_day_moving_average( i , time_period )
				dp.date = c.date
				dp
			end
			Timeseries::Series.new( moving_averages )
		end

		# Gets the moving average for a single day in the series
		#
		# @return [Float] moving average
		def single_day_moving_average offset = 0 , time_period = 7
			self.sum_range( offset , time_period ) / time_period.to_f
		end

		# Generates time series where the DataPoint object values are exponential moving averages
		#
		# @return [TimeSeries::Series] exponential moving average series
		def exponential_moving_average time_period = 7
			averages = self.each_with_index.map do |dp,i|
				Timeseries::DataPoint.new( dp.date , ema( time_period , i ) )
			end
			Timeseries::Series.new( averages )
		end

		# Sorting methods
		def method_missing(name , *args)
			# sort DataPoints ascending or descending based on attribute (date or value)
			if /^sort_by_(\w+)_([^!]+)(!?)$/.match(name)
				sort_field = $1.to_sym
				sort_dir = $2
				bang = $3
				return Timeseries::Series.new( self.send("sort#{bang}".to_sym) { |a,b| a.send(sort_field) <=> b.send(sort_field) } ) if sort_dir =~ /^asc/
				return Timeseries::Series.new( self.send("sort#{bang}".to_sym) { |a,b| b.send(sort_field) <=> a.send(sort_field) } ) if sort_dir =~ /^desc/
			elsif /^([^_]+)_day_((?:exponential_)?moving_average)$/.match(name)
				case $1
				when 'seven'
					return send($2.to_sym , 7)
				end
			end
			super
		end

		# Generates a daily summation of the series
		#
		# @return [Timeseries::Series] a daily version of the current series
		def daily
			grouped = group_by { |dp| dp.date.jd }
			daily_series = grouped.map { |k,v| Timeseries::DataPoint.new( v[0].date , v.inject(0) { |sum,c| sum.to_f + c.value.to_f } )  }
			Timeseries::Series.new( daily_series )
		end

		# Modifies the existing series to become a daily series
		# 	KEEP IN MIND: This will overwrite existing values if you have multiple DataPoints for individual days
		#
		# @return [Timeseries::Series] self
		def daily!
			self.replace( daily )
		end

		# Fills in 0 for any empty dates
		#
		# @return [Timeseries::Series] an 0 filled time series
		def zero_empty_dates
			incomplete_series = daily.sort_by_date_descending!

			daily_series = Timeseries::Series.new

			return daily_series if incomplete_series.length < 2

			( incomplete_series.last.date.jd .. incomplete_series.first.date.jd ).map do |jd_date|
				match = incomplete_series.find { |dp| dp.date.jd == jd_date }
				value = ( match == nil ) ? 0 : match.value
				date = DateTime.jd( jd_date ).midnight
				daily_series.unshift( Timeseries::DataPoint.new( date , value ) )
			end

			daily_series
		end

	private
		def ema time_period = 7 , offset = 0
			# equation:
			#  Multiplier: (2 / (Time periods + 1) ) = (2 / (10 + 1) ) = 0.1818 (18.18%)
			#  EMA: {value - EMA(previous day)} x multiplier + EMA(previous day).
			return nil if offset > ( self.length - time_period )

			# Exponential moving average always uses simple moving average as first value
			return single_day_moving_average( offset , time_period ) if offset == ( self.length - time_period )

			# generate the ema for the given day
			previous_day = offset + 1
			yesterday_ema = ema( time_period , previous_day )
			( self[offset].value - yesterday_ema ) * exponential_multiplier( time_period ) + yesterday_ema
		end

		def data_points_for_jd_day day
			find_all { |dp| dp.date.jd == day }
		end

		def exponential_multiplier time_period = 7
			( 2 / ( time_period.to_f + 1.0 ) )
		end
	end
end