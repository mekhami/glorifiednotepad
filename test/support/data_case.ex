defmodule Indie.DataCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      alias Indie.Repo

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import Indie.DataCase

      def errors_on(changeset) do
        Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
          Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
            opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
          end)
        end)
      end
    end
  end

  setup tags do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(Indie.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
    :ok
  end
end
