class TimeSeries
  class Schema
    attr_reader :index, :types

    def initialize(index:, types:)
      types.each_value do |type|
        raise ArgumentError, "unknown cast type: #{type.inspect}" unless TimeSeries.valid_cast_type?(type)
      end

      unless types.key?(index)
        raise ArgumentError, "index column #{index.inspect} must be included in types"
      end

      if types[index].to_s.end_with?("?")
        raise ArgumentError, "index column #{index.inspect} cannot be nullable"
      end

      @index = index
      @types = types.dup.freeze
      freeze
    end
  end
end
