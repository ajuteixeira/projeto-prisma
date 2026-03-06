defmodule ProjetoPrisma.Repo do
  use Ecto.Repo,
    otp_app: :projeto_prisma,
    adapter: Ecto.Adapters.Postgres
end
