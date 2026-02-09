require "csv"

class TimeSeries
  class Table
    def initialize(data = {})
      data.each_key do |key|
        raise ArgumentError, "column names must be strings, got #{key.class}" unless key.is_a?(String)
      end

      lengths = data.values.map(&:length).uniq
      if lengths.length > 1
        raise ArgumentError, "all columns must have equal length, got #{data.transform_values(&:length)}"
      end

      @data = data.transform_values { |v| v.dup.freeze }
      @columns = data.keys.dup.freeze
      freeze
    end

    def self.from_csv(string)
      csv = CSV.parse(string)
      headers = csv.shift
      return new(headers.to_h { |h| [h, []] }) if csv.empty?
      from_rows headers: headers, rows: csv
    end

    def self.from_rows(headers:, rows:)
      rows.each_with_index do |row, i|
        if row.length != headers.length
          raise ArgumentError, "row #{i} has #{row.length} values, expected #{headers.length}"
        end
      end

      data = headers.each_with_index.to_h { |h, i| [h, rows.map { |r| r[i] }] }
      new data
    end

    attr_reader :columns

    def [](name)
      @data[name]
    end

    def size
      @data.empty? ? 0 : @data.values.first.length
    end

    def empty?
      size == 0
    end

    def to_csv
      CSV.generate do |csv|
        csv << @columns
        size.times { |i| csv << @columns.map { |c| @data[c][i] } }
      end
    end

    def ==(other)
      other.is_a?(Table) && @columns == other.columns && @columns.all? { |c| @data[c] == other[c] }
    end
  end
end
