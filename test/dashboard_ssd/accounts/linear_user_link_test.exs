defmodule DashboardSSD.Accounts.LinearUserLinkTest do
  use DashboardSSD.DataCase, async: true

  alias DashboardSSD.Accounts
  alias DashboardSSD.Accounts.LinearUserLink
  alias DashboardSSD.Projects.LinearTeamMember
  alias DashboardSSD.Projects.LinearTeamMember

  describe "upsert_linear_user_link/2" do
    test "creates a link for a user" do
      {:ok, user} = Accounts.create_user(%{email: "linear+1@example.com", name: "Linear One"})

      {:ok, %LinearUserLink{} = link} =
        Accounts.upsert_linear_user_link(user, %{
          linear_user_id: "lin_1",
          linear_email: "lin.one@example.com",
          linear_name: "Lin One",
          linear_display_name: "Lin One",
          auto_linked: false
        })

      assert link.user_id == user.id
      assert link.linear_user_id == "lin_1"
      refute link.auto_linked
    end

    test "reassigns a Linear user to a different Dashboard account" do
      {:ok, user1} = Accounts.create_user(%{email: "linear+old@example.com", name: "Old"})
      {:ok, user2} = Accounts.create_user(%{email: "linear+new@example.com", name: "New"})

      {:ok, _} =
        Accounts.upsert_linear_user_link(user1, %{
          linear_user_id: "lin_shared",
          linear_email: "shared@example.com"
        })

      {:ok, %LinearUserLink{} = link} =
        Accounts.upsert_linear_user_link(user2, %{
          linear_user_id: "lin_shared",
          linear_email: "shared@example.com"
        })

      assert link.user_id == user2.id
      assert Accounts.get_linear_user_link_by_user_id(user1.id) == nil
      assert Accounts.get_linear_user_link_by_user_id(user2.id).linear_user_id == "lin_shared"
    end

    test "accepts numeric user identifier" do
      {:ok, user} = Accounts.create_user(%{email: "linear+numeric@example.com", name: "Numeric"})

      {:ok, %LinearUserLink{} = link} =
        Accounts.upsert_linear_user_link(user.id, %{
          linear_user_id: "lin_numeric",
          linear_email: "numeric@example.com",
          linear_name: "Numeric User"
        })

      assert link.user_id == user.id
      assert link.linear_user_id == "lin_numeric"
    end

    test "returns changeset error when linear_user_id missing" do
      {:ok, user} = Accounts.create_user(%{email: "linear+invalid@example.com", name: "Invalid"})

      assert {:error, %Ecto.Changeset{} = changeset} =
               Accounts.upsert_linear_user_link(user, %{linear_email: "missing@example.com"})

      assert "can't be blank" in errors_on(changeset).linear_user_id
    end
  end

  describe "unlink_linear_user/1" do
    test "removes link by struct" do
      {:ok, user} = Accounts.create_user(%{email: "unlink+struct@example.com", name: "Struct"})

      {:ok, _} =
        Accounts.upsert_linear_user_link(user, %{
          linear_user_id: "lin_struct",
          linear_email: "struct@example.com"
        })

      assert :ok = Accounts.unlink_linear_user(user)
      assert Accounts.get_linear_user_link_by_user_id(user.id) == nil
    end

    test "removes link by id" do
      {:ok, user} = Accounts.create_user(%{email: "unlink+id@example.com", name: "ID"})

      {:ok, _} =
        Accounts.upsert_linear_user_link(user, %{
          linear_user_id: "lin_id",
          linear_email: "id@example.com"
        })

      assert :ok = Accounts.unlink_linear_user(user.id)
      assert Accounts.get_linear_user_link_by_user_id(user.id) == nil
    end
  end

  describe "linear_roster_with_links/1" do
    test "deduplicates Linear users and annotates link status" do
      Repo.insert!(%LinearTeamMember{
        linear_team_id: "team-1",
        linear_user_id: "lin_a",
        name: "Alpha",
        email: "alpha@example.com"
      })

      Repo.insert!(%LinearTeamMember{
        linear_team_id: "team-2",
        linear_user_id: "lin_a",
        name: "Alpha Duplicate",
        email: "alpha@example.com"
      })

      Repo.insert!(%LinearTeamMember{
        linear_team_id: "team-1",
        linear_user_id: "lin_b",
        name: "Beta",
        email: "beta@example.com"
      })

      {:ok, user} = Accounts.create_user(%{email: "beta@example.com", name: "Beta User"})

      {:ok, _} =
        Accounts.upsert_linear_user_link(user, %{
          linear_user_id: "lin_b",
          linear_email: "beta@example.com"
        })

      roster = Accounts.linear_roster_with_links()

      assert length(roster) == 2

      assert Enum.any?(roster, fn %{member: member, link: link} ->
               member.linear_user_id == "lin_a" and is_nil(link)
             end)

      assert Enum.any?(roster, fn %{member: member, link: link} ->
               member.linear_user_id == "lin_b" and not is_nil(link) and link.user_id == user.id
             end)

      unlinked_only = Accounts.linear_roster_with_links(only_unlinked: true)
      assert Enum.all?(unlinked_only, fn %{link: link} -> is_nil(link) end)
      assert Enum.map(unlinked_only, & &1.member.linear_user_id) == ["lin_a"]
    end
  end

  describe "list/get linear links" do
    test "lists links ordered by inserted_at and preloads users" do
      {:ok, user_a} = Accounts.create_user(%{email: "link-a@example.com", name: "Link A"})
      {:ok, user_b} = Accounts.create_user(%{email: "link-b@example.com", name: "Link B"})

      {:ok, _} =
        Accounts.upsert_linear_user_link(user_b, %{
          linear_user_id: "lin_list_b",
          auto_linked: true
        })

      # Insert second to ensure ordering works
      {:ok, _} =
        Accounts.upsert_linear_user_link(user_a, %{
          linear_user_id: "lin_list_a",
          auto_linked: false
        })

      [first, second] = Accounts.list_linear_user_links()
      assert first.linear_user_id == "lin_list_b"
      assert first.user.email == "link-b@example.com"
      assert second.linear_user_id == "lin_list_a"
      assert second.user.email == "link-a@example.com"
    end

    test "get_linear_user_link_by_user_id/1 returns nil when missing" do
      {:ok, user} = Accounts.create_user(%{email: "nolink@example.com", name: "No Link"})
      assert Accounts.get_linear_user_link_by_user_id(user.id) == nil
    end
  end

  describe "auto_link_linear_member/1" do
    test "auto-links by email ignoring case" do
      {:ok, user} = Accounts.create_user(%{email: "alpha@EXAMPLE.com", name: "Alpha"})

      member = %LinearTeamMember{
        linear_user_id: "lin_auto_1",
        email: "Alpha@example.com",
        name: "Alpha",
        display_name: "Alpha Display"
      }

      assert :ok = Accounts.auto_link_linear_member(member)

      link = Accounts.get_linear_user_link_by_user_id(user.id)
      assert link.linear_user_id == "lin_auto_1"
      assert link.auto_linked
    end

    test "does not override manual links" do
      {:ok, user} = Accounts.create_user(%{email: "manual@example.com", name: "Manual"})

      {:ok, _} =
        Accounts.upsert_linear_user_link(user, %{
          linear_user_id: "lin_manual",
          auto_linked: false
        })

      member = %LinearTeamMember{
        linear_user_id: "lin_other",
        email: "manual@example.com",
        name: "Manual"
      }

      assert {:error, :manual_link_exists} = Accounts.auto_link_linear_member(member)

      link = Accounts.get_linear_user_link_by_user_id(user.id)
      assert link.linear_user_id == "lin_manual"
      refute link.auto_linked
    end

    test "skips when Linear user already linked to someone else" do
      {:ok, user1} = Accounts.create_user(%{email: "first@example.com", name: "First"})
      {:ok, user2} = Accounts.create_user(%{email: "second@example.com", name: "Second"})

      {:ok, _} =
        Accounts.upsert_linear_user_link(user1, %{
          linear_user_id: "lin_shared",
          auto_linked: true
        })

      member = %LinearTeamMember{
        linear_user_id: "lin_shared",
        email: "second@example.com",
        name: "Second"
      }

      assert {:error, :linear_user_linked_to_other_user} =
               Accounts.auto_link_linear_member(member)

      link = Accounts.get_linear_user_link_by_user_id(user1.id)
      assert link.linear_user_id == "lin_shared"
      assert Accounts.get_linear_user_link_by_user_id(user2.id) == nil
    end

    test "errors when Linear user manually linked to another account" do
      {:ok, user1} = Accounts.create_user(%{email: "manual-owner@example.com", name: "Owner"})
      {:ok, user2} = Accounts.create_user(%{email: "manual-seeker@example.com", name: "Seeker"})

      {:ok, _} =
        Accounts.upsert_linear_user_link(user1, %{
          linear_user_id: "lin_manual_claimed",
          auto_linked: false
        })

      member = %LinearTeamMember{
        linear_user_id: "lin_manual_claimed",
        email: "manual-seeker@example.com",
        name: "Seeker"
      }

      assert {:error, :linear_user_manually_linked} = Accounts.auto_link_linear_member(member)

      assert Accounts.get_linear_user_link_by_user_id(user1.id).linear_user_id ==
               "lin_manual_claimed"

      assert Accounts.get_linear_user_link_by_user_id(user2.id) == nil
    end

    test "skips when Linear user id is missing" do
      {:ok, _user} = Accounts.create_user(%{email: "skip@example.com", name: "Skip"})

      member = %LinearTeamMember{
        linear_user_id: nil,
        email: "skip@example.com",
        name: "Skip"
      }

      assert :skip = Accounts.auto_link_linear_member(member)
    end

    test "auto-links by unique name when email does not match" do
      {:ok, user} =
        Accounts.create_user(%{email: "name-fallback@example.com", name: "Name Fallback"})

      member = %LinearTeamMember{
        linear_user_id: "lin_name_fallback",
        email: nil,
        name: "Name Fallback"
      }

      assert :ok = Accounts.auto_link_linear_member(member)

      link = Accounts.get_linear_user_link_by_user_id(user.id)
      assert link.linear_user_id == "lin_name_fallback"
    end
  end
end
