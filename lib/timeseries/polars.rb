require "polars"

class TimeSeries
  POLARS_DTYPE_MAP = {
    date:    Polars::Date,
    time:    Polars::Datetime.new("ms"),
    float64: Polars::Float64,
    integer: Polars::Int64,
    decimal: Polars::Decimal.new(38, 18),
    string:  Polars::String,
  }.freeze

  POLARS_REVERSE_LIST = [
    [Polars::Date, :date],
    [Polars::Datetime.new("ms"), :time],
    [Polars::Float64, :float64],
    [Polars::Int64, :integer],
    [Polars::String, :string],
  ].freeze

  def to_polars
    raise Error, "must cast before converting to Polars" unless cast?

    series_list = @table.columns.map do |col|
      base, _ = parse_type(@types[col])
      dtype = polars_dtype(base)
      values = @table[col]
      values = values.map { |v| v.is_a?(BigDecimal) ? v.to_f : v } if dtype == Polars::Float64
      Polars::Series.new(col, values, dtype: dtype)
    end

    Polars::DataFrame.new(series_list)
  end

  private def polars_dtype(base)
    if (m = DECIMAL_TYPE.match(base.to_s)) && m[1]
      Polars::Decimal.new(m[1].to_i, m[2].to_i)
    else
      POLARS_DTYPE_MAP[base]
    end
  end

  def self.from_polars(df, index:, name: nil, metadata: {})
    types = {}
    data = {}

    df.columns.each do |col|
      s = df[col]
      dtype = s.dtype

      base_type = if dtype.is_a?(Polars::Decimal)
        :"decimal(#{dtype.precision || 38},#{dtype.scale})"
      else
        POLARS_REVERSE_LIST.find { |d, _| d == dtype }&.last
      end
      if base_type
        types[col] = col == index ? base_type : :"#{base_type}?"
      end

      data[col] = s.to_a
    end

    table = Table.new(data)
    series = new(table: table, index: index, name: name, metadata: metadata)
    series.cast(**types)
  end
end
