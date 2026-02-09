require 'spec_helper'

describe Timeseries::DataPoint do
	before { @point = Timeseries::DataPoint.new( DateTime.new , 123 ) }

	subject { @point }

	it { is_expected.to respond_to(:date) }
	it { is_expected.to respond_to(:value) }
end