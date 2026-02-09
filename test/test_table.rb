require "test_helper"

class TestTable < Minitest::Test
  def setup
    @data = {
      "date"   => ["2024-01-01", "2024-01-02", "2024-01-03"],
      "close"  => ["100.12345", "101.6780", "99.00100"],
      "volume" => ["14200", "8900", "22010"],
    }
    @table = TimeSeries::Table.new(@data)
  end

  def test_columns_returns_ordered_names
    assert_equal ["date", "close", "volume"], @table.columns
  end

  def test_bracket_access_returns_column_array
    assert_equal ["100.12345", "101.6780", "99.00100"], @table["close"]
  end

  def test_bracket_access_returns_nil_for_unknown_column
    assert_nil @table["nonexistent"]
  end

  def test_size_returns_row_count
    assert_equal 3, @table.size
  end

  def test_empty_returns_false_for_nonempty_table
    refute @table.empty?
  end

  def test_empty_returns_true_for_empty_table
    table = TimeSeries::Table.new("date" => [], "close" => [])
    assert table.empty?
  end

  def test_equality
    other = TimeSeries::Table.new(@data)
    assert_equal @table, other
  end

  def test_inequality_different_data
    other = TimeSeries::Table.new(
      "date" => ["2024-01-01"],
      "close" => ["100"],
      "volume" => ["14200"],
    )
    refute_equal @table, other
  end

  def test_inequality_different_columns
    other = TimeSeries::Table.new(
      "date" => ["2024-01-01", "2024-01-02", "2024-01-03"],
      "price" => ["100.12345", "101.6780", "99.00100"],
    )
    refute_equal @table, other
  end

  def test_raises_on_unequal_column_lengths
    assert_raises(ArgumentError) do
      TimeSeries::Table.new(
        "date"  => ["2024-01-01", "2024-01-02"],
        "close" => ["100"],
      )
    end
  end

  def test_raises_on_non_string_column_names
    assert_raises(ArgumentError) do
      TimeSeries::Table.new(date: ["2024-01-01"])
    end
  end

  def test_frozen_after_construction
    assert @table.frozen?
  end

  def test_column_arrays_frozen
    assert @table["close"].frozen?
  end

  def test_zero_columns_allowed
    table = TimeSeries::Table.new({})
    assert_equal 0, table.size
    assert table.empty?
    assert_equal [], table.columns
  end

  def test_from_rows
    table = TimeSeries::Table.from_rows(
      headers: ["date", "close", "volume"],
      rows: [
        ["2024-01-01", "100.12345", "14200"],
        ["2024-01-02", "101.6780", "8900"],
        ["2024-01-03", "99.00100", "22010"],
      ],
    )
    assert_equal @table, table
  end

  def test_from_rows_empty
    table = TimeSeries::Table.from_rows(headers: ["date", "close"], rows: [])
    assert table.empty?
    assert_equal ["date", "close"], table.columns
  end

  def test_from_rows_validates_row_width
    assert_raises(ArgumentError) do
      TimeSeries::Table.from_rows(
        headers: ["date", "close"],
        rows: [["2024-01-01", "100", "extra"]],
      )
    end
  end

  def test_to_csv
    csv = @table.to_csv
    expected = "date,close,volume\n2024-01-01,100.12345,14200\n2024-01-02,101.6780,8900\n2024-01-03,99.00100,22010\n"
    assert_equal expected, csv
  end

  def test_from_csv
    csv = "date,close,volume\n2024-01-01,100.12345,14200\n2024-01-02,101.6780,8900\n2024-01-03,99.00100,22010\n"
    table = TimeSeries::Table.from_csv(csv)
    assert_equal @table, table
  end

  def test_csv_round_trip
    csv = @table.to_csv
    round_tripped = TimeSeries::Table.from_csv(csv)
    assert_equal @table, round_tripped
  end

  def test_from_csv_empty_body
    csv = "date,close\n"
    table = TimeSeries::Table.from_csv(csv)
    assert table.empty?
    assert_equal ["date", "close"], table.columns
  end

  def test_csv_with_quoted_fields
    table = TimeSeries::Table.new(
      "name" => ["foo,bar", "baz"],
      "value" => ["1", "2"],
    )
    round_tripped = TimeSeries::Table.from_csv(table.to_csv)
    assert_equal table, round_tripped
  end

  def test_csv_round_trip_with_nils
    table = TimeSeries::Table.new(
      "date"  => ["2024-01-01", "2024-01-02", "2024-01-03"],
      "close" => ["100.5", nil, "99.0"],
    )
    csv = table.to_csv
    round_tripped = TimeSeries::Table.from_csv(csv)
    assert_equal table, round_tripped
  end

  def test_from_csv_empty_cells_become_nil
    csv = "date,close\n2024-01-01,100.5\n2024-01-02,\n2024-01-03,99.0\n"
    table = TimeSeries::Table.from_csv(csv)
    assert_equal ["100.5", nil, "99.0"], table["close"]
  end
end
