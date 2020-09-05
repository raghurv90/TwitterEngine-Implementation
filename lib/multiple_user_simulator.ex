defmodule MultipleUserSimulator do
  use GenServer

  def start_link(simulator_number) do
    name = {:via, Registry, {Registry.TwitterRegistry, "simulator_"<>to_string(simulator_number)}}
    GenServer.start_link(__MODULE__, simulator_number, name: name )
  end

  def init(simulator_number) do
    {:ok, simulator_number}
  end

  def simulate_tweets(simulator_number, total_simulators, no_tweets, no_users) do
    pid = RegistryHelper.get_simulator_pid(simulator_number)
    # IO.puts("before cast #{simulator_number}")
    GenServer.cast(pid, {:simulate_tweets, simulator_number, total_simulators, no_tweets, no_users})
  end

  def handle_cast({:simulate_tweets, simulator_number, total_simulators, no_tweets, no_users}, state) do
    start_user = 1+div((simulator_number*no_users),total_simulators)
    end_user = div(((simulator_number+1)*no_users), total_simulators)
    # IO.puts("start_user #{start_user} end_user #{end_user}  ")

    # start_user..end_user |> Enum.each(fn x-> User.login(x, "password") end)
    # start_user..end_user |> Enum.each(fn x-> IO.puts("#{x}") end)

    start_user..end_user |> Enum.each(fn x-> User.simulate_tweets(x, "password", no_tweets, no_users) end)
    {:noreply, state}
  end

  def handle_call({:processed?}, _from, state) do
		{:reply, true, state}
	end



end
