defmodule MainSupervisor do
  use Supervisor

  # dont forget this
# mix deps.get

  def start_link(_id) do
		Supervisor.start_link(__MODULE__, restart: :transient)
	end

  def init(_id) do
	  {:ok, _} = Registry.start_link(keys: :unique, name: Registry.TwitterRegistry)

    newc = [Supervisor.child_spec(AccountManager, id: 1,  type: :worker),
                  Supervisor.child_spec(TwitterEngine, id: 2,  type: :worker)]
    Supervisor.init(newc, strategy: :one_for_one, restart: :transient)
  end

end
