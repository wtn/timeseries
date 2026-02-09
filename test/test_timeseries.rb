require "test_helper"

class TestTimeSeriesVersion < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::TimeSeries::VERSION
  end
end

class TestTimeSeries < Minitest::Test
  def setup
    @table = TimeSeries::Table.new(
      "date"   => ["2024-01-01", "2024-01-02", "2024-01-03"],
      "close"  => ["100.12345", "101.6780", "99.00100"],
      "volume" => ["14200", "8900", "22010"],
    )
    @series = TimeSeries.new(
      table: @table,
      index: "date",
      name: "SPX Daily Close",
      metadata: { source: "cboe", frequency: "daily" },
    )
  end

  def test_table_accessor
    assert_equal @table, @series.table
  end

  def test_index_returns_column_name
    assert_equal "date", @series.index
  end

  def test_name_accessor
    assert_equal "SPX Daily Close", @series.name
  end

  def test_metadata_accessor
    assert_equal({ source: "cboe", frequency: "daily" }, @series.metadata)
  end

  def test_bracket_access_delegates_to_table
    assert_equal ["100.12345", "101.6780", "99.00100"], @series["close"]
  end

  def test_size_delegates_to_table
    assert_equal 3, @series.size
  end

  def test_empty_delegates_to_table
    refute @series.empty?
  end

  def test_cast_is_false_before_casting
    refute @series.cast?
  end

  def test_types_is_nil_before_casting
    assert_nil @series.types
  end

  def test_raises_on_invalid_index_column
    assert_raises(ArgumentError) do
      TimeSeries.new(table: @table, index: "nonexistent")
    end
  end

  def test_name_defaults_to_nil
    series = TimeSeries.new(table: @table, index: "date")
    assert_nil series.name
  end

  def test_metadata_defaults_to_empty_hash
    series = TimeSeries.new(table: @table, index: "date")
    assert_equal({}, series.metadata)
  end

  def test_frozen_after_construction
    assert @series.frozen?
  end

  def test_metadata_frozen
    assert @series.metadata.frozen?
  end
end

class TestTimeSeriesCast < Minitest::Test
  def setup
    @table = TimeSeries::Table.new(
      "date"   => ["2024-01-01", "2024-01-02", "2024-01-03"],
      "close"  => ["100.12345", "101.6780", "99.00100"],
      "volume" => ["14200", "8900", "22010"],
    )
    @series = TimeSeries.new(table: @table, index: "date")
  end

  def test_cast_date
    typed = @series.cast("date" => :date)
    assert_equal [Date.new(2024, 1, 1), Date.new(2024, 1, 2), Date.new(2024, 1, 3)], typed["date"]
  end

  def test_cast_time
    table = TimeSeries::Table.new(
      "ts"    => ["2024-01-01T12:00:00Z", "2024-01-02T12:00:00Z"],
      "value" => ["1", "2"],
    )
    series = TimeSeries.new(table: table, index: "ts")
    typed = series.cast("ts" => :time)
    assert_equal Time.utc(2024, 1, 1, 12), typed["ts"][0]
    assert_equal Time.utc(2024, 1, 2, 12), typed["ts"][1]
  end

  def test_cast_float64
    typed = @series.cast("date" => :date, "close" => :float64)
    assert_equal [100.12345, 101.678, 99.001], typed["close"]
    assert_instance_of Float, typed["close"][0]
  end

  def test_cast_integer
    typed = @series.cast("date" => :date, "volume" => :integer)
    assert_equal [14200, 8900, 22010], typed["volume"]
    assert_instance_of Integer, typed["volume"][0]
  end

  def test_cast_decimal
    typed = @series.cast("date" => :date, "close" => :decimal)
    assert_equal BigDecimal("100.12345"), typed["close"][0]
    assert_instance_of BigDecimal, typed["close"][0]
  end

  def test_cast_parameterized_decimal
    typed = @series.cast("date" => :date, "close" => :"decimal(18,9)")
    assert_equal BigDecimal("100.12345"), typed["close"][0]
    assert_instance_of BigDecimal, typed["close"][0]
  end

  def test_cast_parameterized_decimal_nullable
    table = TimeSeries::Table.new(
      "date"  => ["2024-01-01", "2024-01-02"],
      "price" => ["1.5", nil],
    )
    series = TimeSeries.new(table: table, index: "date")
    typed = series.cast("date" => :date, "price" => :"decimal(18,9)?")
    assert_equal BigDecimal("1.5"), typed["price"][0]
    assert_nil typed["price"][1]
  end

  def test_cast_malformed_decimal_raises
    assert_raises(ArgumentError) { @series.cast("date" => :date, "close" => :"decimal(18)") }
    assert_raises(ArgumentError) { @series.cast("date" => :date, "close" => :"decimal(x,y)") }
  end

  def test_cast_string_is_noop
    typed = @series.cast("date" => :date, "volume" => :string)
    assert_equal ["14200", "8900", "22010"], typed["volume"]
  end

  def test_cast_returns_new_timeseries
    typed = @series.cast("date" => :date, "close" => :float64)
    assert_instance_of TimeSeries, typed
    refute_same @series, typed
  end

  def test_cast_preserves_name_and_metadata
    series = TimeSeries.new(table: @table, index: "date", name: "test", metadata: { x: 1 })
    typed = series.cast("date" => :date)
    assert_equal "test", typed.name
    assert_equal({ x: 1 }, typed.metadata)
  end

  def test_cast_sets_types
    typed = @series.cast("date" => :date, "close" => :float64, "volume" => :integer)
    assert_equal({ "date" => :date, "close" => :float64, "volume" => :integer }, typed.types)
  end

  def test_cast_question_true_after_casting
    typed = @series.cast("date" => :date)
    assert typed.cast?
  end

  def test_cast_auto_sorts_index
    table = TimeSeries::Table.new(
      "date"  => ["2024-01-03", "2024-01-01", "2024-01-02"],
      "value" => ["3", "1", "2"],
    )
    series = TimeSeries.new(table: table, index: "date")
    typed = series.cast("date" => :date, "value" => :integer)
    assert_equal [Date.new(2024, 1, 1), Date.new(2024, 1, 2), Date.new(2024, 1, 3)], typed["date"]
    assert_equal [1, 2, 3], typed["value"]
  end

  def test_cast_already_sorted_unchanged
    typed = @series.cast("date" => :date, "close" => :float64)
    assert_equal [Date.new(2024, 1, 1), Date.new(2024, 1, 2), Date.new(2024, 1, 3)], typed["date"]
    assert_equal [100.12345, 101.678, 99.001], typed["close"]
  end

  def test_cast_sort_false_raises_on_unsorted
    table = TimeSeries::Table.new(
      "date"  => ["2024-01-03", "2024-01-01", "2024-01-02"],
      "value" => ["1", "2", "3"],
    )
    series = TimeSeries.new(table: table, index: "date")
    assert_raises(TimeSeries::Error) { series.cast("date" => :date, sort: false) }
  end

  def test_cast_sort_false_raises_on_duplicate
    table = TimeSeries::Table.new(
      "date"  => ["2024-01-01", "2024-01-01", "2024-01-02"],
      "value" => ["1", "2", "3"],
    )
    series = TimeSeries.new(table: table, index: "date")
    assert_raises(TimeSeries::Error) { series.cast("date" => :date, sort: false) }
  end

  def test_cast_enforces_unique_index
    table = TimeSeries::Table.new(
      "date"  => ["2024-01-01", "2024-01-01", "2024-01-02"],
      "value" => ["1", "2", "3"],
    )
    series = TimeSeries.new(table: table, index: "date")
    assert_raises(TimeSeries::Error) { series.cast("date" => :date) }
  end

  def test_cast_raises_on_bad_value
    table = TimeSeries::Table.new(
      "date"  => ["2024-01-01", "not-a-date"],
      "value" => ["1", "2"],
    )
    series = TimeSeries.new(table: table, index: "date")
    assert_raises { series.cast("date" => :date) }
  end

  def test_cast_raises_on_unknown_type
    assert_raises(ArgumentError) { @series.cast("date" => :unknown) }
  end

  def test_cast_passthrough_date_objects
    table = TimeSeries::Table.new(
      "date"  => [Date.new(2024, 1, 1), Date.new(2024, 1, 2)],
      "value" => ["1", "2"],
    )
    series = TimeSeries.new(table: table, index: "date")
    typed = series.cast("date" => :date)
    assert_equal Date.new(2024, 1, 1), typed["date"][0]
  end

  def test_cast_passthrough_time_objects
    t1 = Time.utc(2024, 1, 1)
    t2 = Time.utc(2024, 1, 2)
    table = TimeSeries::Table.new(
      "ts"    => [t1, t2],
      "value" => ["1", "2"],
    )
    series = TimeSeries.new(table: table, index: "ts")
    typed = series.cast("ts" => :time)
    assert_equal t1, typed["ts"][0]
  end

  def test_uncast_columns_preserved_as_is
    typed = @series.cast("date" => :date)
    assert_equal ["100.12345", "101.6780", "99.00100"], typed["close"]
    assert_equal ["14200", "8900", "22010"], typed["volume"]
  end

  # Non-nullable types reject nil
  def test_cast_nil_raises_float64
    table = TimeSeries::Table.new(
      "date"  => ["2024-01-01", "2024-01-02", "2024-01-03"],
      "close" => ["100.5", nil, "99.0"],
    )
    series = TimeSeries.new(table: table, index: "date")
    assert_raises(TimeSeries::Error) { series.cast("date" => :date, "close" => :float64) }
  end

  def test_cast_nil_raises_integer
    table = TimeSeries::Table.new(
      "date"   => ["2024-01-01", "2024-01-02"],
      "volume" => [nil, "8900"],
    )
    series = TimeSeries.new(table: table, index: "date")
    assert_raises(TimeSeries::Error) { series.cast("date" => :date, "volume" => :integer) }
  end

  def test_cast_nil_raises_date
    table = TimeSeries::Table.new(
      "date"  => ["2024-01-01", "2024-01-02"],
      "other" => [nil, "2024-06-15"],
    )
    series = TimeSeries.new(table: table, index: "date")
    assert_raises(TimeSeries::Error) { series.cast("date" => :date, "other" => :date) }
  end

  def test_cast_nil_raises_time
    table = TimeSeries::Table.new(
      "date"  => ["2024-01-01", "2024-01-02"],
      "ts"    => ["2024-01-01T12:00:00Z", nil],
    )
    series = TimeSeries.new(table: table, index: "date")
    assert_raises(TimeSeries::Error) { series.cast("date" => :date, "ts" => :time) }
  end

  def test_cast_nil_raises_decimal
    table = TimeSeries::Table.new(
      "date"  => ["2024-01-01", "2024-01-02"],
      "price" => [nil, "100.50"],
    )
    series = TimeSeries.new(table: table, index: "date")
    assert_raises(TimeSeries::Error) { series.cast("date" => :date, "price" => :decimal) }
  end

  def test_cast_nil_raises_string
    table = TimeSeries::Table.new(
      "date" => ["2024-01-01", "2024-01-02"],
      "note" => ["hello", nil],
    )
    series = TimeSeries.new(table: table, index: "date")
    assert_raises(TimeSeries::Error) { series.cast("date" => :date, "note" => :string) }
  end

  # Nullable types pass nil through
  def test_cast_nil_passthrough_float64_nullable
    table = TimeSeries::Table.new(
      "date"  => ["2024-01-01", "2024-01-02", "2024-01-03"],
      "close" => ["100.5", nil, "99.0"],
    )
    series = TimeSeries.new(table: table, index: "date")
    typed = series.cast("date" => :date, "close" => :float64?)
    assert_equal [100.5, nil, 99.0], typed["close"]
  end

  def test_cast_nil_passthrough_integer_nullable
    table = TimeSeries::Table.new(
      "date"   => ["2024-01-01", "2024-01-02"],
      "volume" => [nil, "8900"],
    )
    series = TimeSeries.new(table: table, index: "date")
    typed = series.cast("date" => :date, "volume" => :integer?)
    assert_equal [nil, 8900], typed["volume"]
  end

  def test_cast_nil_passthrough_date_nullable
    table = TimeSeries::Table.new(
      "date"  => ["2024-01-01", "2024-01-02"],
      "other" => [nil, "2024-06-15"],
    )
    series = TimeSeries.new(table: table, index: "date")
    typed = series.cast("date" => :date, "other" => :date?)
    assert_equal [nil, Date.new(2024, 6, 15)], typed["other"]
  end

  def test_cast_nil_passthrough_time_nullable
    table = TimeSeries::Table.new(
      "date"  => ["2024-01-01", "2024-01-02"],
      "ts"    => ["2024-01-01T12:00:00Z", nil],
    )
    series = TimeSeries.new(table: table, index: "date")
    typed = series.cast("date" => :date, "ts" => :time?)
    assert_equal [Time.utc(2024, 1, 1, 12), nil], typed["ts"]
  end

  def test_cast_nil_passthrough_decimal_nullable
    table = TimeSeries::Table.new(
      "date"  => ["2024-01-01", "2024-01-02"],
      "price" => [nil, "100.50"],
    )
    series = TimeSeries.new(table: table, index: "date")
    typed = series.cast("date" => :date, "price" => :decimal?)
    assert_equal [nil, BigDecimal("100.50")], typed["price"]
  end

  def test_cast_nil_passthrough_string_nullable
    table = TimeSeries::Table.new(
      "date" => ["2024-01-01", "2024-01-02"],
      "note" => ["hello", nil],
    )
    series = TimeSeries.new(table: table, index: "date")
    typed = series.cast("date" => :date, "note" => :string?)
    assert_equal ["hello", nil], typed["note"]
  end

  def test_cast_nullable_type_is_valid
    typed = @series.cast("date" => :date, "close" => :float64?)
    assert_equal :float64?, typed.types["close"]
  end

  def test_cast_nullable_index_raises
    assert_raises(ArgumentError) { @series.cast("date" => :date?) }
  end

  def test_cast_nil_in_index_raises
    table = TimeSeries::Table.new(
      "date"  => ["2024-01-01", nil, "2024-01-03"],
      "value" => ["1", "2", "3"],
    )
    series = TimeSeries.new(table: table, index: "date")
    assert_raises(TimeSeries::Error) { series.cast("date" => :date) }
  end
end
