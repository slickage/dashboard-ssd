alias DashboardSSD.Accounts
alias DashboardSSD.Auth.Capabilities

# Ensure the canonical roles exist
Enum.each(["admin", "employee", "client"], &Accounts.ensure_role!/1)

# Apply default capability assignments
Capabilities.default_assignments()
|> Enum.each(fn {role_name, capability_codes} ->
  {:ok, _} = Accounts.replace_role_capabilities(role_name, capability_codes)
end)
