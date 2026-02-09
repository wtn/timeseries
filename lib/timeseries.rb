require "date"
require "time"
require "bigdecimal"

require_relative "timeseries/version"
require_relative "timeseries/table"
require_relative "timeseries/schema"

class TimeSeries
  class Error < StandardError; end

  BASE_CAST_TYPES = %i[date time float64 integer decimal string].freeze
  CAST_TYPES = (BASE_CAST_TYPES + BASE_CAST_TYPES.map { |t| :"#{t}?" }).freeze

  # Bare :decimal plus parameterized forms like :"decimal(18,9)"
  DECIMAL_TYPE = /\Adecimal(?:\((\d+),\s*(\d+)\))?\??\z/

  def self.valid_cast_type?(type)
    CAST_TYPES.include?(type) || type.to_s.match?(DECIMAL_TYPE)
  end

  def self.decimal_type?(base)
    base.to_s.match?(DECIMAL_TYPE)
  end

  def self.from_table(table, schema:, name: nil, metadata: {}, sort: true)
    series = new(table: table, index: schema.index, name: name, metadata: metadata)
    series.cast(**schema.types, sort: sort)
  end

  attr_reader :table, :index, :name, :metadata, :types

  def initialize(table:, index:, name: nil, metadata: {})
    unless table.columns.include?(index)
      raise ArgumentError, "index column #{index.inspect} not found in table columns: #{table.columns.inspect}"
    end

    @table = table
    @index = index
    @name = name
    @metadata = metadata.freeze
    @types = nil
    freeze
  end

  def [](name)
    @table[name]
  end

  def size
    @table.size
  end

  def empty?
    @table.empty?
  end

  def cast?
    !@types.nil?
  end

  def cast(sort: true, **type_map)
    type_map.each_value do |type|
      raise ArgumentError, "unknown cast type: #{type.inspect}" unless self.class.valid_cast_type?(type)
    end

    if type_map.key?(@index) && type_map[@index].to_s.end_with?("?")
      raise ArgumentError, "index column #{@index.inspect} cannot be nullable"
    end

    new_data = {}
    @table.columns.each do |col|
      values = @table[col]
      new_data[col] = if type_map.key?(col)
        values.map { |v| coerce v, type_map[col] }
      else
        values
      end
    end

    if type_map.key?(@index)
      index_col = new_data[@index]
      raise Error, "nil value in index column #{@index.inspect}" if index_col.any?(&:nil?)

      needs_sort = index_col.each_cons(2).any? { |a, b| (a <=> b) > 0 }

      if needs_sort
        raise Error, "index not sorted" unless sort
        order = (0...index_col.length).sort_by { |i| index_col[i] }
        new_data = new_data.transform_values { |col| order.map { |i| col[i] } }
      end

      new_data[@index].each_cons(2) do |a, b|
        raise Error, "duplicate index value: #{a.inspect}" if a == b
      end
    end

    new_table = Table.new(new_data)
    _build_cast(table: new_table, types: type_map)
  end

  private

  def _build_cast(table:, types:)
    copy = self.class.allocate
    copy.instance_variable_set :@table, table
    copy.instance_variable_set :@index, @index
    copy.instance_variable_set :@name, @name
    copy.instance_variable_set :@metadata, @metadata
    copy.instance_variable_set :@types, types.freeze
    copy.freeze
  end

  def coerce(value, type)
    base, nullable = parse_type(type)

    if value.nil?
      raise Error, "nil value for non-nullable type #{type.inspect}" unless nullable
      return nil
    end

    case base
    when :date
      value.is_a?(Date) ? value : Date.iso8601(value)
    when :time
      value.is_a?(Time) ? value : Time.parse(value).utc
    when :float64
      Float(value)
    when :integer
      Integer(value)
    when :string
      value
    else # :decimal or :"decimal(p,s)" -- validated in cast
      BigDecimal(value.to_s)
    end
  end

  def parse_type(type)
    str = type.to_s
    if str.end_with?("?")
      [str.chomp("?").to_sym, true]
    else
      [type, false]
    end
  end
end
