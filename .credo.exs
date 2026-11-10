%{
  configs: [
    %{
      name: "default",
      files: %{
        included: ["lib/", "src/", "test/", "web/"],
        excluded: [~r"/_build/", ~r"/deps/", ~r"/node_modules/"]
      },
      plugins: [],
      #
      # CodeMySpec ships framework checks into
      # `.code_my_spec/credo_checks/framework/`; put your own project checks
      # in `.code_my_spec/credo_checks/local/`. Both directories are loaded
      # before analysis so the checks below can resolve.
      #
      requires: [
        ".code_my_spec/credo_checks/framework/**/*.ex",
        ".code_my_spec/credo_checks/local/**/*.ex"
      ],
      strict: false,
      parse_timeout: 5000,
      color: true,
      #
      # The framework check list is data, not code: the harness rewrites
      # `checks.exs` as checks are added or retired, and this file picks the
      # new list up without being edited. The `File.exists?` guard keeps
      # `mix credo` working before the harness has installed anything.
      #
      # `extra` overrides the params of a default check of the same name
      # (`ConfigFile.merge_checks/2` is a `Keyword.merge`), which is how the
      # spex exclusion below reconfigures a stock check rather than replacing
      # the default set.
      #
      checks: %{
        #
        # `Credo.Check.Warning.WrongTestFilename` (EX5030) flags any file
        # under `test/` that uses an ExUnit case template and is not named
        # `*_test.exs`. Every acceptance spec in a CodeMySpec project is
        # named `*_spex.exs` by design — `mix spex`'s own default pattern is
        # `test/spex/**/*_spex.exs`, and the `bdd_specs_exist` task dictates
        # those exact paths — so the check fires on every one of them.
        # Measured on one project: 282 findings, all of them the convention
        # working correctly.
        #
        # Reconfigured rather than disabled. What it is actually for — a
        # test file `mix test` will silently skip because it is misnamed —
        # is still worth catching; it just has one more valid ending here.
        #
        # Guarded because the check is newer than some pinned credos (absent
        # in 1.7.15, present in 1.7.19), and naming a module that does not
        # exist would break `mix credo` for everyone on the older one.
        extra:
          if(File.exists?(".code_my_spec/credo_checks/framework/checks.exs"),
            do: elem(Code.eval_file(".code_my_spec/credo_checks/framework/checks.exs"), 0),
            else: []
          ) ++
            if Code.ensure_loaded?(Credo.Check.Warning.WrongTestFilename) do
              [
                {Credo.Check.Warning.WrongTestFilename,
                 files: %{
                   excluded: [
                     "test/**/*_test.exs",
                     "apps/**/test/**/*_test.exs",
                     "test/**/*_spex.exs",
                     "apps/**/test/**/*_spex.exs"
                   ]
                 }}
              ]
            else
              []
            end
      }
    }
  ]
}
