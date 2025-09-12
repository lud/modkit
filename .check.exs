[
  parallel: true,
  skipped: false,
  fix: false,
  retry: false,
  tools: [
    {:compiler, true},
    {:doctor, false},
    {:gettext, false},
    {:credo, "mix credo --all --strict"}
  ]
]
