defmodule DashboardSSD.DataCaseHelperTest do
  use DashboardSSD.DataCase, async: true

  alias DashboardSSD.Accounts.User
  alias DashboardSSD.DataCase

  test "errors_on/1 formats changeset messages" do
    changeset = User.changeset(%User{}, %{})
    errors = DataCase.errors_on(changeset)
    assert "can't be blank" in errors.email
  end
end
