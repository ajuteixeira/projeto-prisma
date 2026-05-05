defmodule ProjetoPrisma.Accounts.PinnedAchievementsTest do
  use ProjetoPrisma.DataCase, async: true

  import ProjetoPrisma.AccountsFixtures

  alias ProjetoPrisma.Accounts
  alias ProjetoPrisma.Accounts.{Profile, ProfileAchievement, ProfileGame}
  alias ProjetoPrisma.Catalog.{Achievement, Game, Platform, PlatformGame}

  describe "list_achieved_achievements/2" do
    test "lists only achieved achievements owned by the current user" do
      %{scope: scope, profile_game: profile_game, platform_game: platform_game} =
        library_fixture()

      achieved = profile_achievement_fixture(profile_game, platform_game, name: "First Win")

      unachieved =
        profile_achievement_fixture(profile_game, platform_game, name: "Locked", achieved: false)

      %{profile_game: other_profile_game, platform_game: other_platform_game} = library_fixture()

      other_user_achievement =
        profile_achievement_fixture(other_profile_game, other_platform_game)

      achievements = Accounts.list_achieved_achievements(scope)

      assert Enum.map(achievements, & &1.profile_achievement_id) == [achieved.id]
      refute Enum.any?(achievements, &(&1.profile_achievement_id == unachieved.id))
      refute Enum.any?(achievements, &(&1.profile_achievement_id == other_user_achievement.id))
    end

    test "filters by achievement name" do
      %{scope: scope, profile_game: profile_game, platform_game: platform_game} =
        library_fixture(game_name: "Same Game")

      treasure = profile_achievement_fixture(profile_game, platform_game, name: "Treasure Hunter")
      profile_achievement_fixture(profile_game, platform_game, name: "Speed Runner")

      achievements = Accounts.list_achieved_achievements(scope, search: "treasure")

      assert Enum.map(achievements, & &1.profile_achievement_id) == [treasure.id]
    end

    test "filters by game name" do
      %{scope: scope, profile: profile, platform: platform} =
        library_fixture(game_name: "First Game")

      first_game = game_fixture(name: "Mystic Quest")
      second_game = game_fixture(name: "Space Quest")
      first_platform_game = platform_game_fixture(platform, first_game)
      second_platform_game = platform_game_fixture(platform, second_game)
      first_profile_game = profile_game_fixture(profile, first_platform_game)
      second_profile_game = profile_game_fixture(profile, second_platform_game)

      mystic =
        profile_achievement_fixture(first_profile_game, first_platform_game, name: "Explorer")

      profile_achievement_fixture(second_profile_game, second_platform_game, name: "Pilot")

      achievements = Accounts.list_achieved_achievements(scope, search: "mystic")

      assert Enum.map(achievements, & &1.profile_achievement_id) == [mystic.id]
      assert hd(achievements).game_name == "Mystic Quest"
    end
  end

  describe "list_pinned_achievements/1" do
    test "lists pinned achievements ordered by pinned position" do
      %{scope: scope, profile_game: profile_game, platform_game: platform_game} =
        library_fixture()

      first = profile_achievement_fixture(profile_game, platform_game, pinned_position: 2)
      second = profile_achievement_fixture(profile_game, platform_game, pinned_position: 1)
      profile_achievement_fixture(profile_game, platform_game)

      achievements = Accounts.list_pinned_achievements(scope)

      assert Enum.map(achievements, & &1.profile_achievement_id) == [second.id, first.id]
      assert Enum.map(achievements, & &1.pinned_position) == [1, 2]
    end
  end

  describe "update_pinned_achievements/2" do
    test "saves one pinned achievement" do
      %{scope: scope, profile_game: profile_game, platform_game: platform_game} =
        library_fixture()

      achievement = profile_achievement_fixture(profile_game, platform_game)

      assert {:ok, [pinned]} = Accounts.update_pinned_achievements(scope, [achievement.id])
      assert pinned.profile_achievement_id == achievement.id
      assert pinned.pinned_position == 1
      assert Repo.reload!(achievement).pinned_position == 1
    end

    test "saves four pinned achievements in submitted order" do
      %{scope: scope, profile_game: profile_game, platform_game: platform_game} =
        library_fixture()

      achievements = create_profile_achievements(profile_game, platform_game, 4)
      ids = achievements |> Enum.reverse() |> Enum.map(& &1.id)

      assert {:ok, pinned} = Accounts.update_pinned_achievements(scope, ids)

      assert Enum.map(pinned, & &1.profile_achievement_id) == ids
      assert Enum.map(pinned, & &1.pinned_position) == [1, 2, 3, 4]
    end

    test "accepts string ids from form params" do
      %{scope: scope, profile_game: profile_game, platform_game: platform_game} =
        library_fixture()

      achievement = profile_achievement_fixture(profile_game, platform_game)

      assert {:ok, [pinned]} =
               Accounts.update_pinned_achievements(scope, [to_string(achievement.id)])

      assert pinned.profile_achievement_id == achievement.id
    end

    test "saving an empty selection clears existing pins" do
      %{scope: scope, profile_game: profile_game, platform_game: platform_game} =
        library_fixture()

      achievement = profile_achievement_fixture(profile_game, platform_game, pinned_position: 1)

      assert {:ok, []} = Accounts.update_pinned_achievements(scope, [])
      assert is_nil(Repo.reload!(achievement).pinned_position)
    end

    test "clears old pins when a new selection is saved" do
      %{scope: scope, profile_game: profile_game, platform_game: platform_game} =
        library_fixture()

      old_first = profile_achievement_fixture(profile_game, platform_game, pinned_position: 1)
      old_second = profile_achievement_fixture(profile_game, platform_game, pinned_position: 2)
      new_pin = profile_achievement_fixture(profile_game, platform_game)

      assert {:ok, [pinned]} = Accounts.update_pinned_achievements(scope, [new_pin.id])

      assert pinned.profile_achievement_id == new_pin.id
      assert is_nil(Repo.reload!(old_first).pinned_position)
      assert is_nil(Repo.reload!(old_second).pinned_position)
      assert Repo.reload!(new_pin).pinned_position == 1
    end

    test "rejects more than four achievements" do
      %{scope: scope, profile_game: profile_game, platform_game: platform_game} =
        library_fixture()

      ids = profile_game |> create_profile_achievements(platform_game, 5) |> Enum.map(& &1.id)

      assert {:error, :too_many_pins} = Accounts.update_pinned_achievements(scope, ids)
      assert [] = Accounts.list_pinned_achievements(scope)
    end

    test "rejects another user's achievement ids" do
      %{scope: scope} = library_fixture()
      %{profile_game: other_profile_game, platform_game: other_platform_game} = library_fixture()
      other_achievement = profile_achievement_fixture(other_profile_game, other_platform_game)

      assert {:error, :invalid_achievement_selection} =
               Accounts.update_pinned_achievements(scope, [other_achievement.id])
    end

    test "rejects unachieved achievement ids" do
      %{scope: scope, profile_game: profile_game, platform_game: platform_game} =
        library_fixture()

      unachieved = profile_achievement_fixture(profile_game, platform_game, achieved: false)

      assert {:error, :invalid_achievement_selection} =
               Accounts.update_pinned_achievements(scope, [unachieved.id])
    end
  end

  defp library_fixture(opts \\ []) do
    user = user_fixture()
    scope = user_scope_fixture(user)
    profile = profile_fixture(user)
    platform = platform_fixture()
    game = game_fixture(name: Keyword.get(opts, :game_name, "Game #{unique_integer()}"))
    platform_game = platform_game_fixture(platform, game)
    profile_game = profile_game_fixture(profile, platform_game)

    %{
      user: user,
      scope: scope,
      profile: profile,
      platform: platform,
      game: game,
      platform_game: platform_game,
      profile_game: profile_game
    }
  end

  defp profile_fixture(user) do
    %Profile{}
    |> Profile.changeset(%{username: "user_#{unique_integer()}", user_id: user.id})
    |> Repo.insert!()
  end

  defp platform_fixture do
    id = unique_integer()

    %Platform{}
    |> Platform.changeset(%{name: "Platform #{id}", slug: "platform-#{id}"})
    |> Repo.insert!()
  end

  defp game_fixture(attrs \\ []) do
    %Game{}
    |> Game.changeset(%{name: Keyword.get(attrs, :name, "Game #{unique_integer()}")})
    |> Repo.insert!()
  end

  defp platform_game_fixture(platform, game) do
    %PlatformGame{}
    |> PlatformGame.changeset(%{
      platform_id: platform.id,
      game_id: game.id,
      external_game_id: "game-#{unique_integer()}"
    })
    |> Repo.insert!()
  end

  defp profile_game_fixture(profile, platform_game) do
    %ProfileGame{}
    |> ProfileGame.changeset(%{
      profile_id: profile.id,
      platform_game_id: platform_game.id,
      playtime_minutes: 120,
      last_played: ~N[2026-05-01 12:00:00]
    })
    |> Repo.insert!()
  end

  defp profile_achievement_fixture(profile_game, platform_game, attrs \\ []) do
    achievement = achievement_fixture(platform_game, attrs)

    %ProfileAchievement{}
    |> ProfileAchievement.changeset(%{
      profile_game_id: profile_game.id,
      achievement_id: achievement.id,
      achieved: Keyword.get(attrs, :achieved, true),
      unlock_time: Keyword.get(attrs, :unlock_time, ~N[2026-05-01 13:00:00]),
      pinned_position: Keyword.get(attrs, :pinned_position)
    })
    |> Repo.insert!()
  end

  defp achievement_fixture(platform_game, attrs) do
    id = unique_integer()

    %Achievement{}
    |> Achievement.changeset(%{
      platform_game_id: platform_game.id,
      external_achievement_id: "achievement-#{id}",
      name: Keyword.get(attrs, :name, "Achievement #{id}"),
      description: Keyword.get(attrs, :description, "Achievement description"),
      icon_image: Keyword.get(attrs, :icon_image, "https://example.com/#{id}.png")
    })
    |> Repo.insert!()
  end

  defp create_profile_achievements(profile_game, platform_game, count) do
    Enum.map(1..count, fn index ->
      profile_achievement_fixture(profile_game, platform_game, name: "Achievement #{index}")
    end)
  end

  defp unique_integer, do: System.unique_integer([:positive])
end
