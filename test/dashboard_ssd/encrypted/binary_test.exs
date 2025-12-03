defmodule DashboardSSD.Encrypted.BinaryTest do
  use ExUnit.Case, async: true

  alias DashboardSSD.Encrypted.Binary

  test "type delegates to :binary" do
    assert Binary.type() == :binary
  end
end
