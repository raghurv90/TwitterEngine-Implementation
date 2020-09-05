[no_users, no_tweets] = Enum.map(System.argv(), fn(n) -> String.to_integer(n) end)
MainSupervisor.start_link(1)

1..no_users+1 |> Enum.each(fn x->AccountManager.register_account(x,"password") end)
GenServer.call(:account_manager, {:processed?})
1..no_users |> Enum.each(fn x-> User.login(x, "password") end)

pid = RegistryHelper.get_user_pid(no_users);
GenServer.call(pid, {:processed?})

simulation_start_time = Time.utc_now()

1..no_users |> Enum.each(fn x->
        # no_of_followers = div(no_users, x+1)
        no_of_followers = max(no_users-1, 5)

        followers = Enum.take_random(1..no_users, no_of_followers)
        followers |> Enum.filter(fn y-> y !=x end)
                  |> Enum.each(fn follower -> User.subscribe_to_user(follower, "password", x) end)
          end)

no_of_simulators = 10
0..(no_of_simulators-1) |> Enum.each(fn x-> MultipleUserSimulator.start_link(x) end)

# 1..no_users |> Enum.each(fn x-> User.logout(x, "password") end)
# 1..no_users |> Enum.each(fn x-> User.simulate_tweets(x, "password", no_tweets, no_users) end)
0..no_of_simulators |>
Enum.each(fn x-> MultipleUserSimulator.simulate_tweets(x, no_of_simulators, no_tweets, no_users) end)

#
# 1..no_users |> Enum.each(fn x->
#   pid = RegistryHelper.get_user_pid(x)
#   if(pid==nil) do
#     IO.puts("pid null for username #{x}")
#   else
#     GenServer.call(pid, {:processed?}, 2100000)
#   end
#    end)


0..no_of_simulators-1 |> Enum.each(fn x->
  pid = RegistryHelper.get_simulator_pid(x)
  if(pid==nil) do
    IO.puts("pid null for simulator #{x}")
  else
    GenServer.call(pid, {:processed?}, 2130000)
    # IO.puts("Simulator #{x} is processed")
  end
   end)





 pid = RegistryHelper.get_user_pid(no_users);
 GenServer.call(pid, {:processed?})
 time_diff = Time.diff(Time.utc_now(), simulation_start_time, :millisecond)

 IO.puts("The time taken for only tweeting is #{time_diff} milliseconds")

GenServer.call(:account_manager, {:processed?}, 2000000)
GenServer.call(:twitter_engine, {:processed?}, 2000000)
time_diff = Time.diff(Time.utc_now(), simulation_start_time, :millisecond)
IO.puts("The time takem for simulation is #{time_diff} milliseconds")
