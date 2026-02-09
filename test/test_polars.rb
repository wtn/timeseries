require "test_helper"

begin
  require "polars"
  require "timeseries/polars"
  HAS_POLARS = true
rescue LoadError
  HAS_POLARS = false
end

class TestPolars < Minitest::Test
  def setup
    skip "polars-df not available" unless HAS_POLARS

    @table = TimeSeries::Table.new(
      "date"   => ["2024-01-01", "2024-01-02", "2024-01-03"],
      "close"  => ["100.12345", "101.6780", "99.00100"],
      "volume" => ["14200", "8900", "22010"],
    )
    @schema = TimeSeries::Schema.new(
      index: "date",
      types: {
        "date"   => :date,
        "close"  => :float64,
        "volume" => :integer,
      },
    )
    @series = TimeSeries.from_table(@table, schema: @schema, name: "test")
  end

  def test_to_polars_returns_dataframe
    df = @series.to_polars
    assert_instance_of Polars::DataFrame, df
  end

  def test_to_polars_columns
    df = @series.to_polars
    assert_equal ["date", "close", "volume"], df.columns
  end

  def test_to_polars_date_dtype
    df = @series.to_polars
    assert_equal Polars::Date, df["date"].dtype
  end

  def test_to_polars_float64_dtype
    df = @series.to_polars
    assert_equal Polars::Float64, df["close"].dtype
  end

  def test_to_polars_integer_dtype
    df = @series.to_polars
    assert_equal Polars::Int64, df["volume"].dtype
  end

  def test_to_polars_date_values
    df = @series.to_polars
    assert_equal [Date.new(2024, 1, 1), Date.new(2024, 1, 2), Date.new(2024, 1, 3)], df["date"].to_a
  end

  def test_to_polars_float_values
    df = @series.to_polars
    assert_equal [100.12345, 101.678, 99.001], df["close"].to_a
  end

  def test_to_polars_integer_values
    df = @series.to_polars
    assert_equal [14200, 8900, 22010], df["volume"].to_a
  end

  def test_to_polars_with_time_column
    table = TimeSeries::Table.new(
      "ts"    => ["2024-01-01T12:00:00Z", "2024-01-02T12:00:00Z"],
      "value" => ["1.5", "2.5"],
    )
    schema = TimeSeries::Schema.new(
      index: "ts",
      types: { "ts" => :time, "value" => :float64 },
    )
    series = TimeSeries.from_table(table, schema: schema)
    df = series.to_polars
    assert_equal Polars::Datetime.new("ms"), df["ts"].dtype
  end

  def test_to_polars_with_decimal_column
    table = TimeSeries::Table.new(
      "date"  => ["2024-01-01"],
      "price" => ["100.12345"],
    )
    schema = TimeSeries::Schema.new(
      index: "date",
      types: { "date" => :date, "price" => :decimal },
    )
    series = TimeSeries.from_table(table, schema: schema)
    df = series.to_polars
    assert_equal Polars::Decimal.new(38, 18), df["price"].dtype
    assert_equal BigDecimal("100.12345"), df["price"].to_a[0]
  end

  def test_to_polars_with_parameterized_decimal_column
    table = TimeSeries::Table.new(
      "date"  => ["2024-01-01"],
      "price" => ["100.000000001"],
    )
    schema = TimeSeries::Schema.new(
      index: "date",
      types: { "date" => :date, "price" => :"decimal(18,9)" },
    )
    series = TimeSeries.from_table(table, schema: schema)
    df = series.to_polars
    assert_equal Polars::Decimal.new(18, 9), df["price"].dtype
    assert_equal BigDecimal("100.000000001"), df["price"].to_a[0]
  end

  def test_decimal_round_trip
    table = TimeSeries::Table.new(
      "date"  => ["2024-01-01", "2024-01-02"],
      "price" => ["100.000000001", "99.5"],
    )
    schema = TimeSeries::Schema.new(
      index: "date",
      types: { "date" => :date, "price" => :"decimal(18,9)" },
    )
    series = TimeSeries.from_table(table, schema: schema)
    restored = TimeSeries.from_polars(series.to_polars, index: "date")
    assert_equal :"decimal(18,9)?", restored.types["price"]
    assert_equal BigDecimal("100.000000001"), restored["price"][0]
    assert_instance_of BigDecimal, restored["price"][0]
  end

  def test_decimal_round_trip_through_parquet
    require "tmpdir"

    table = TimeSeries::Table.new(
      "date"  => ["2024-01-01"],
      "price" => ["100.000000001"],
    )
    schema = TimeSeries::Schema.new(
      index: "date",
      types: { "date" => :date, "price" => :"decimal(18,9)" },
    )
    series = TimeSeries.from_table(table, schema: schema)

    Dir.mktmpdir do |dir|
      path = File.join(dir, "test.parquet")
      series.to_polars.write_parquet path
      restored = TimeSeries.from_polars(Polars.read_parquet(path), index: "date")
      assert_equal BigDecimal("100.000000001"), restored["price"][0]
      assert_equal :"decimal(18,9)?", restored.types["price"]
    end
  end

  def test_to_polars_with_string_column
    table = TimeSeries::Table.new(
      "date" => ["2024-01-01"],
      "note" => ["hello"],
    )
    schema = TimeSeries::Schema.new(
      index: "date",
      types: { "date" => :date, "note" => :string },
    )
    series = TimeSeries.from_table(table, schema: schema)
    df = series.to_polars
    assert_equal Polars::String, df["note"].dtype
  end

  def test_to_polars_requires_cast
    raw = TimeSeries.new(table: @table, index: "date")
    assert_raises(TimeSeries::Error) { raw.to_polars }
  end

  def test_from_polars_round_trip
    df = @series.to_polars
    restored = TimeSeries.from_polars(df, index: "date", name: "restored")
    assert_equal "restored", restored.name
    assert_equal "date", restored.index
    assert restored.cast?
    assert_equal @series["date"], restored["date"]
    assert_equal @series["close"], restored["close"]
    assert_equal @series["volume"], restored["volume"]
  end

  def test_from_polars_types
    df = @series.to_polars
    restored = TimeSeries.from_polars(df, index: "date")
    assert_equal :date, restored.types["date"]
    assert_equal :float64?, restored.types["close"]
    assert_equal :integer?, restored.types["volume"]
  end

  def test_from_polars_metadata
    df = @series.to_polars
    restored = TimeSeries.from_polars(df, index: "date", metadata: { source: "test" })
    assert_equal({ source: "test" }, restored.metadata)
  end
end
