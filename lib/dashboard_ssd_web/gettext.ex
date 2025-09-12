defmodule DashboardSSDWeb.Gettext do
  @moduledoc """
  Gettext backend for internationalization.

  To use translation macros in a module, do:

      use Gettext, backend: DashboardSSDWeb.Gettext

  See the Gettext docs for details.
  """
  use Gettext.Backend, otp_app: :dashboard_ssd
end
