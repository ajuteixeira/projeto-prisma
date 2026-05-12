defmodule ProjetoPrismaWeb.Router do
  use ProjetoPrismaWeb, :router

  import ProjetoPrismaWeb.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {ProjetoPrismaWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_scope_for_user
    plug :assign_current_path
  end

  # Injeta o path atual nos assigns para que a sidebar possa destacar o item ativo
  defp assign_current_path(conn, _opts) do
    Plug.Conn.assign(conn, :current_path, conn.request_path)
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", ProjetoPrismaWeb do
    pipe_through [:browser, :require_authenticated_user]

    get "/", PageController, :profile
    get "/connect-platforms", PageController, :connect_platforms
    get "/followers", PageController, :followers

    get "/auth/xbox/start", XboxOAuthController, :start
    get "/auth/xbox/callback", XboxOAuthController, :callback
  end

  scope "/", ProjetoPrismaWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    get "/register", PageController, :register
    post "/complete-registration", PageController, :complete_registration
    post "/register", PageController, :create_profile
    get "/reset-password", UserResetPasswordController, :new
    post "/reset-password", UserResetPasswordController, :create
    get "/reset-password/:token", UserResetPasswordController, :edit
    put "/reset-password/:token", UserResetPasswordController, :update
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:projeto_prisma, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: ProjetoPrismaWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes

  scope "/", ProjetoPrismaWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    get "/users/register", UserRegistrationController, :new
    post "/users/register", UserRegistrationController, :create
  end

  scope "/", ProjetoPrismaWeb do
    pipe_through [:browser, :require_authenticated_user]

    get "/users/settings", UserSettingsController, :edit
    put "/users/settings", UserSettingsController, :update
    delete "/users/settings", UserSettingsController, :delete
    get "/users/settings/confirm-email/:token", UserSettingsController, :confirm_email
  end

  scope "/", ProjetoPrismaWeb do
    pipe_through [:browser]

    get "/log-in", UserSessionController, :new
    get "/log-in/:token", UserSessionController, :confirm
    post "/log-in", UserSessionController, :create
    get "/log-out", UserSessionController, :delete
    delete "/log-out", UserSessionController, :delete

    get "/users/log-in", UserSessionController, :new
    get "/users/log-in/:token", UserSessionController, :confirm
    post "/users/log-in", UserSessionController, :create
    get "/users/log-out", UserSessionController, :delete
    delete "/users/log-out", UserSessionController, :delete
  end
end
