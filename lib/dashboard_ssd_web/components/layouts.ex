defmodule DashboardSSDWeb.Layouts do
  @moduledoc """
  This module holds different layouts used by your application.

  See the `layouts` directory for all templates available.
  The "root" layout is a skeleton rendered as part of the
  application router. The "app" layout is set as the default
  layout on both `use DashboardSSDWeb, :controller` and
  `use DashboardSSDWeb, :live_view`.
  """
  use DashboardSSDWeb, :html

  embed_templates "layouts/*"

  @doc false
  @spec header_action_classes(atom()) :: String.t()
  def header_action_classes(:primary) do
    "inline-flex items-center gap-2 rounded-full bg-theme-primary px-4 py-2 text-sm font-semibold text-white shadow-theme-soft transition hover:bg-theme-primary-soft"
  end

  def header_action_classes(:ghost) do
    "inline-flex items-center gap-2 rounded-full border border-white/10 bg-white/5 px-4 py-2 text-sm font-medium text-theme-text transition hover:border-white/20 hover:bg-white/10"
  end

  def header_action_classes(_variant), do: header_action_classes(:ghost)

  @doc false
  @spec default_header_actions(nil | map()) :: [map()]
  def default_header_actions(nil) do
    [
      %{label: "Sign in", href: ~p"/auth/google", variant: :primary}
    ]
  end

  def default_header_actions(_user) do
    [
      %{label: "Log out", href: ~p"/logout", variant: :ghost}
    ]
  end

  @doc false
  @spec user_initials(nil | %{optional(:name) => String.t(), optional(:email) => String.t()}) ::
          String.t()
  def user_initials(nil), do: "?"

  def user_initials(%{name: name}) when is_binary(name) and name != "" do
    name
    |> String.split()
    |> Enum.map_join("", &String.first/1)
    |> String.upcase()
  end

  def user_initials(%{email: email}) when is_binary(email) and email != "" do
    email
    |> String.first()
    |> String.upcase()
  end

  def user_initials(_), do: "?"

  @doc false
  @spec user_display_name(nil | %{optional(:name) => String.t(), optional(:email) => String.t()}) ::
          String.t() | nil
  def user_display_name(nil), do: nil

  def user_display_name(%{name: name} = user) when is_binary(name) do
    case String.trim(name) do
      "" -> user_display_name(%{email: Map.get(user, :email)})
      trimmed -> trimmed
    end
  end

  def user_display_name(%{email: email}) when is_binary(email) and email != "" do
    email
  end

  def user_display_name(_), do: nil

  @doc "Returns the capitalized role name for the user."
  @spec user_role(nil | %{optional(:role) => %{optional(:name) => String.t()}}) ::
          String.t() | nil
  def user_role(nil), do: nil

  def user_role(%{role: %{name: name}}) when is_binary(name) do
    String.capitalize(name)
  end

  def user_role(_), do: nil
end
