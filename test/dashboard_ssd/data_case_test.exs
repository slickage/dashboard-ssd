defmodule DashboardSSD.DataCaseTest do
  use ExUnit.Case, async: true

  alias DashboardSSD.DataCase

  defmodule ErrorsSchema do
    use Ecto.Schema

    embedded_schema do
      field :name, :string
    end
  end

  import Ecto.Changeset

  test "errors_on normalizes changeset errors" do
    changeset =
      %ErrorsSchema{}
      |> cast(%{}, [:name])
      |> validate_required([:name])

    assert %{name: ["can't be blank"]} = DataCase.errors_on(changeset)
  end
end
