defmodule Indie.Repo.Migrations.CreateComments do
  use Ecto.Migration

  def change do
    create table(:comments) do
      add(:post_id, :string, null: false)
      add(:author_name, :string, size: 50, null: false)
      add(:body, :text, null: false)

      timestamps(type: :utc_datetime)
    end

    create(index(:comments, [:post_id]))
    create(index(:comments, [:inserted_at]))
  end
end
