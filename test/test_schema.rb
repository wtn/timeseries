require "test_helper"

class TestSchema < Minitest::Test
  def test_construction
    schema = TimeSeries::Schema.new(
      index: "date",
      types: {
        "date"   => :date,
        "close"  => :float64,
        "volume" => :integer,
      },
    )
    assert_equal "date", schema.index
    assert_equal({ "date" => :date, "close" => :float64, "volume" => :integer }, schema.types)
  end

  def test_frozen
    schema = TimeSeries::Schema.new(index: "date", types: { "date" => :date })
    assert schema.frozen?
    assert schema.types.frozen?
  end

  def test_validates_types
    assert_raises(ArgumentError) do
      TimeSeries::Schema.new(index: "date", types: { "date" => :bogus })
    end
  end

  def test_validates_index_in_types
    assert_raises(ArgumentError) do
      TimeSeries::Schema.new(index: "date", types: { "close" => :float64 })
    end
  end

  def test_accepts_nullable_types
    schema = TimeSeries::Schema.new(
      index: "date",
      types: { "date" => :date, "close" => :float64? },
    )
    assert_equal :float64?, schema.types["close"]
  end

  def test_accepts_parameterized_decimal
    schema = TimeSeries::Schema.new(
      index: "date",
      types: { "date" => :date, "price" => :"decimal(18,9)?" },
    )
    assert_equal :"decimal(18,9)?", schema.types["price"]
  end

  def test_rejects_malformed_decimal
    assert_raises(ArgumentError) do
      TimeSeries::Schema.new(index: "date", types: { "date" => :date, "price" => :"decimal(18)" })
    end
  end

  def test_rejects_nullable_index
    assert_raises(ArgumentError) do
      TimeSeries::Schema.new(index: "date", types: { "date" => :date? })
    end
  end
end

class TestFromTable < Minitest::Test
  def setup
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
  end

  def test_from_table_applies_schema
    series = TimeSeries.from_table(@table, schema: @schema)
    assert series.cast?
    assert_equal [Date.new(2024, 1, 1), Date.new(2024, 1, 2), Date.new(2024, 1, 3)], series["date"]
    assert_equal [100.12345, 101.678, 99.001], series["close"]
    assert_equal [14200, 8900, 22010], series["volume"]
  end

  def test_from_table_sets_index_from_schema
    series = TimeSeries.from_table(@table, schema: @schema)
    assert_equal "date", series.index
  end

  def test_from_table_passes_name_and_metadata
    series = TimeSeries.from_table(@table, schema: @schema, name: "SPX", metadata: { source: "cboe" })
    assert_equal "SPX", series.name
    assert_equal({ source: "cboe" }, series.metadata)
  end

  def test_from_table_sets_types_from_schema
    series = TimeSeries.from_table(@table, schema: @schema)
    assert_equal({ "date" => :date, "close" => :float64, "volume" => :integer }, series.types)
  end
end
