defmodule MobaWeb.DuelLiveView do
  use MobaWeb, :live_view

  def mount(%{"id" => duel_id}, %{"user_id" => user_id}, socket) do
    socket = assign_new(socket, :current_user, fn -> Accounts.get_user!(user_id) end)

    if connected?(socket) do
      MobaWeb.subscribe("duel-#{duel_id}")
    end

    duel = Game.get_duel!(duel_id)

    {:ok,
     assign(socket,
       duel: duel,
       heroes: Game.eligible_heroes_for_pvp(user_id),
       first_battle: Engine.first_duel_battle(duel),
       last_battle: Engine.last_duel_battle(duel)
     )}
  end

  def handle_info({"phase", phase}, socket) when phase in ["opponent_first_pick", "user_second_pick"] do
    duel = Game.get_duel!(socket.assigns.duel.id)
    {:noreply, assign(socket, duel: duel)}
  end

  def handle_info({"phase", phase}, %{assigns: %{duel: duel}} = socket)
      when phase in ["user_battle", "opponent_battle"] do
    duel = Game.get_duel!(duel.id)
    battle = Engine.latest_duel_battle(duel.id)
    {:noreply, push_redirect(socket, to: "/battles/#{battle.id}")}
  end

  def handle_event("pick", %{"id" => hero_id}, %{assigns: %{duel: duel}} = socket) do
    Game.next_duel_phase!(duel, String.to_integer(hero_id))

    {:noreply, socket}
  end

  def handle_event("rematch", _, %{assigns: %{duel: duel, current_user: current_user}} = socket) do
    other = if current_user.id == duel.user_id, do: duel.opponent, else: duel.user

    Game.duel_challenge(current_user, other)

    {:noreply, socket}
  end

  def handle_event("switch-build", %{"id" => hero_id}, %{assigns: %{heroes: heroes}} = socket) do
    id = String.to_integer(hero_id)
    index = Enum.find_index(heroes, fn hero -> hero.id == id end)
    hero = Enum.find(heroes, fn hero -> hero.id == id end)
    updated = List.replace_at(heroes, index, Game.switch_build!(hero))

    {:noreply, assign(socket, heroes: updated)}
  end

  def render(assigns) do
    MobaWeb.DuelView.render("show.html", assigns)
  end
end
