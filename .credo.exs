%{
  configs: [
    %{
      name: "default",
      files: %{
        included: ["lib/", "test/", "config/"],
        excluded: [~r"_build/", ~r"deps/"]
      },
      checks: [
        {Credo.Check.Readability.ModuleDoc, false},
        {Credo.Check.Readability.MaxLineLength, max_length: 120},
        {Credo.Check.Warning.IoInspect, false}
      ]
    }
  ]
}

