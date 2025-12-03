defmodule DashboardSSDWeb.PageHTML do
  @moduledoc """
  This module contains pages rendered by PageController.

    - Embeds HEEx template partials for marketing/static pages.
  - Keeps static page rendering concerns separate from LiveView layouts.
  - Provides a compile-time boundary for assets used by PageController.

  See the `page_html` directory for all templates available.
  """
  use DashboardSSDWeb, :html

  embed_templates "page_html/*"
end
