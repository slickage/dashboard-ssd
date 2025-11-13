defmodule DashboardSSDWeb.Gettext do
  @moduledoc """
  Gettext backend for internationalization.

    - Hosts compiled PO files and translation macros for the web layer.
  - Provides gettext macros (`gettext/2`, `ngettext/4`, etc.) once `use`d.
  - Centralizes locale configuration under `:dashboard_ssd`.

  To use translation macros in a module, do:

      use Gettext, backend: DashboardSSDWeb.Gettext

  See the Gettext docs for details.
  """
  use Gettext.Backend, otp_app: :dashboard_ssd
end
