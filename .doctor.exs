%Doctor.Config{
  ignore_modules: [],
  ignore_paths: ["priv/", "assets/"],
  min_module_doc_coverage: 80,
  min_module_spec_coverage: 0,
  min_overall_doc_coverage: 60,
  min_overall_moduledoc_coverage: 98,
  min_overall_spec_coverage: 0,
  exception_moduledoc_required: true,
  raise: true,
  reporter: Doctor.Reporters.Summary,
  struct_type_spec_required: false,
  umbrella: false
}
