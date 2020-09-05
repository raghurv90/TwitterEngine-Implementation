defmodule User do
  use GenServer

  def start_link(username, password) do
      name = {:via, Registry, {Registry.TwitterRegistry, username}}
      GenServer.start_link(__MODULE__, {username, password}, name: name )
  end

  def init({username, password}) do
		{:ok, %{:username => username, :password => password, :notifications => []}}
  end

  def login(username, password) do
    pid = RegistryHelper.get_user_pid(username);
    authenticated? = TwitterEngine.check_authentication(username, password)
      cond do
        !authenticated? ->
          # IO.puts("Invalid credentials")
          {false, nil}
        pid !=nil      ->
          # IO.puts("already logged in")
          {false, nil}
        true           -> User.start_link(username, password)
      end
  end

  def check_logged_in?(username, password) do
    pid = RegistryHelper.get_user_pid(username);
    authenticated? = TwitterEngine.check_authentication(username, password)
    cond do
      !authenticated? ->
        # IO.puts("Invalid credentials")
        false
      pid != nil     ->
        Process.alive?(pid)
      pid == nil     -> false
      true -> false
    end

  end

  def get_pid_if_alive(username) do
    pid = RegistryHelper.get_user_pid(username);
    cond do
      pid != nil && Process.alive?(pid) -> pid
      pid == nil     -> nil
      true -> nil
    end
  end



  def logout(username, _password) do
    #check authentication first here
    pid = RegistryHelper.get_user_pid(username);
      cond do
        pid != nil -> GenServer.stop(pid, :normal, :infinity)
        true      -> false
      end
  end

  def tweet(username, password, message) do
    logged_in? = check_logged_in?(username, password)
    cond do
      logged_in? ->
        pid = RegistryHelper.get_user_pid(username);
        GenServer.call(pid, {:tweet_message, message})
      true -> nil
    end
  end

  #This retweets the last tweet of the celebrity(cannot retweet a retweet, can only retweet from the original tweet)
  def retweet(username, password, celebrity_name) do

    logged_in? = check_logged_in?(username, password)
    cond do
      logged_in? ->
        pid = RegistryHelper.get_user_pid(username);
        GenServer.call(pid, {:retweet_message, celebrity_name})
      true -> nil
    end
  end


  def handle_call({:retweet_message, celebrity_name},_from, state) do
    {retweet_id, message} = retweet_and_get_id(state[:username], celebrity_name)
    cond do
      retweet_id != nil ->
        TwitterEngine.distribute_retweet(state[:username], message)
      true -> nil
    end
    {:reply, retweet_id, state}
	end

  def retweet_and_get_id(username, celebrity_name) do
    celebrity_tweets = :ets.match_object(:tweets, {:"$1", celebrity_name, :_, :_})
                        |> Enum.sort(fn{_x1,_y1,_z1,time1},{_x2,_y2,_z2,time2} -> time1>time2 end)
    cond do
      celebrity_tweets != nil && celebrity_tweets !=[] ->
        {celebrity_last_tweet_id, _, message, _} = celebrity_tweets |> Enum.at(0)
        retweet_time =  DateTime.utc_now
        retweet_id = UUID.uuid1()
        :ets.insert(:retweets, {retweet_id, username, celebrity_last_tweet_id, celebrity_name, retweet_time})
        {retweet_id, message}
      true -> {nil, nil}
    end
  end


  def handle_call({:tweet_message, message},_from, state) do
    tweet_id = UUID.uuid1()
    tweet_time =  DateTime.utc_now
    username = state[:username]
    :ets.insert(:tweets, {tweet_id, username, message, tweet_time})
    TwitterEngine.process_message(username, tweet_id, message)
    {:reply, tweet_id, state}
	end

  def subscribe_to_user(username, password, celebrity_name) do
    logged_in? = check_logged_in?(username, password)
    celebrity_exists? = AccountManager.user_exists?(celebrity_name)
    if(logged_in? && celebrity_exists? && username != celebrity_name) do
      pid = RegistryHelper.get_user_pid(username);
      GenServer.cast(pid, {:subscribe_to_user, username, celebrity_name})
    end
  end

  def handle_cast({:subscribe_to_user, username, celebrity_name}, state) do
    # IO.puts("Inside subscribing celebrity #{celebrity_name} for user #{username}")
    GenServer.cast(:account_manager, {:subscribe_to_user, username, celebrity_name})
    {:noreply, state}
  end

  def handle_cast({:send_tweet_notification, message}, state) do
    notifications = [message] ++ state[:notifications]
    state =  %{state | notifications: notifications}
    # IO.puts("#{message}")
    {:noreply, state}
  end

  def handle_call({:processed?}, _from, state) do
		{:reply, true, state}
	end

  def get_notifications(username) do
    pid = get_pid_if_alive(username)
    cond do
      pid != nil ->
         GenServer.call(pid, {:get_notifications}, 3000000)
      true -> []
    end
  end

  def handle_call({:get_notifications}, _from, state) do
		{:reply, state[:notifications], state}
	end

  def query_tweets(currentuser, password, queryType, query_parameter) do
    logged_in? = check_logged_in?(currentuser, password)
    cond do
      logged_in? ->
        pid = RegistryHelper.get_user_pid(currentuser);
        GenServer.call(pid, {:query_tweets, queryType, query_parameter})
      true -> []
    end
  end


  def handle_call({:query_tweets, queryType, query_parameter}, _from, state) do
    tweets =
      case queryType do
        :get_subscribed_tweets -> get_subscribed_tweets(query_parameter)
        :get_hash_tagged_tweets -> get_hash_tagged_tweets(query_parameter)
        :get_mentioned_tweets -> get_mentioned_tweets(query_parameter)
      end
		{:reply, tweets, state}
	end

  def get_mentioned_tweets(username) do
    # IO.puts("username is #{username}")

    mentioned_tweet_ids = :ets.match(:mentions, {username, :"$1"}) |> Enum.map(fn [x] -> x end)
    # IO.puts("mentioned tweetIds are #{inspect mentioned_tweet_ids}")
    cond do
      mentioned_tweet_ids !=nil && mentioned_tweet_ids != [] ->
        all_tweets = :ets.match_object(:tweets, {:_, :_, :_, :_})
        all_tweets
        |> Enum.map(fn {tweet_id, _username, message, tweet_time} -> {tweet_id, message, tweet_time} end)
        |> Enum.filter(fn {tweet_id, _message, _tweet_time} -> Enum.member?(mentioned_tweet_ids, tweet_id) end)
        |> Enum.sort(fn{_x1,_y1,time1},{_x2,_y2,time2} -> time1<time2 end)
        |> Enum.map(fn {_tweet_id, message, _tweet_time} -> message end)
      true-> []
    end
  end

  def get_hash_tagged_tweets(hash_tag) do
    hash_tagged_tweet_ids = :ets.match(:hash_tags, {hash_tag, :"$1"}) |> Enum.map(fn [x] -> x end)
    cond do
      hash_tagged_tweet_ids !=nil && hash_tagged_tweet_ids != [] ->
        all_tweets = :ets.match_object(:tweets, {:_, :_, :_, :_})
        all_tweets
        |> Enum.map(fn {tweet_id, _username, message, tweet_time} -> {tweet_id, message, tweet_time} end)
        |> Enum.filter(fn {tweet_id, _message, _tweet_time} -> Enum.member?(hash_tagged_tweet_ids, tweet_id) end)
        |> Enum.sort(fn{_x1,_y1,time1},{_x2,_y2,time2} -> time1<time2 end)
        |> Enum.map(fn {_tweet_id, message, _tweet_time} -> message end)
      true-> []
    end
  end



  def get_subscribed_tweets(username) do
    subscriptions = get_subscriptions(username)
    # IO.puts("all subscriptions #{inspect subscriptions}")

    tweets = :ets.match_object(:tweets, {:_, :_, :_, :_})
    # IO.puts("all tweets in the system #{inspect tweets}")
    tweet_ids = tweets |> Enum.map(fn {tweet_id, username, _message, _tweet_time} -> {username, tweet_id} end)
    retweet_ids = :ets.match_object(:retweets, {:_, :_, :_, :_, :_})
              |> Enum.map(fn {_retweet_id, username, actual_tweet_id, _celebrity_name, _retweet_time} -> {username, actual_tweet_id} end)
    all_subscribed_tweet_ids = tweet_ids ++ retweet_ids


    all_subscribed_tweet_ids = all_subscribed_tweet_ids
                            |> Enum.filter(fn {username, _tweet_id} ->Enum.member?(subscriptions, username) end)
                            |> Enum.map(fn {_username, tweet_id} -> tweet_id end)
                            |> Enum.uniq()

    # IO.puts("all subscribed tweet_ids #{inspect all_subscribed_tweet_ids}")

    messages_to_send = tweets
    |> Enum.filter(fn {tweet_id, _username, _message, _tweet_time} -> Enum.member?(all_subscribed_tweet_ids, tweet_id) end)
    |> Enum.map(fn {_tweet_id, _username, message, _tweet_time} -> message end)
    messages_to_send
  end

  def get_subscriptions(username) do
    :ets.match(:subscriptions, {username, :"$1"}) |> Enum.map(fn [x] -> x end)
  end


  # def get_tweet(username, key) do
  #   pid = RegistryHelper.get_user_pid(username)
  #   GenServer.call(pid, {:get_tweet, key}, 3000000)
  # end

  # def handle_call({:get_tweet, key}, _from, state) do
  #   table_id = Map.get(state, :table_id)
  #   {:reply, :ets.lookup(table_id, "welcome_tweet"), state}
	# end


  def simulate_tweets(username, password, no_of_tweets, no_of_users) do
    _logged_in? = check_logged_in?(username, password)

    cond do
      # logged_in? -> User.logout(username, password)
      true ->
        User.login(username, password)
        _pid = RegistryHelper.get_user_pid(username);
        # IO.puts("before tweeting for user #{username}")

        # GenServer.cast(pid, {:simulate_tweets, no_of_tweets, no_of_users})
        simulate_tweets_now(username, password, no_of_tweets, no_of_users)
    end
  end

  def simulate_tweets_now(username, _password, no_of_tweets, no_of_users) do
    hash_tags = ["#DOS", "#Gainesville", "#UF", "#2019", "#TGIF", "#football", "#happy",
          "#busylife", "#America", "#thanksgiving", "#freedom", "#friend", "#HalaMadrid", "#GoGators" ]
    _no_of_followers = :ets.match(:subscriptions, {:_, username})
    no_of_retweets = div(no_of_tweets,10)+1
    IO.puts("tweeting for user #{username}")
    # IO.puts("#{username}")

    1..no_of_tweets |> Enum.each(fn _x ->User.tweet(username, "password", getRandomMessage(hash_tags, no_of_users)) end)
    1..no_of_retweets |> Enum.each(fn _x -> retweet(username, "password", Enum.random(1..no_of_users)) end)
  end

  # def handle_cast({:simulate_tweets, no_of_tweets, no_of_users}, state) do
  #   hash_tags = ["#DOS", "#Gainesville", "#UF", "#2019", "#TGIF", "#football", "#happy",
  #         "#busylife", "#America", "#thanksgiving", "#freedom", "#friend", "#HalaMadrid", "#GoGators" ]
  #   no_of_followers = :ets.match(:subscriptions, {:_, state[:username]})
  #   no_of_retweets = div(no_of_tweets,10)+1
  #   1..no_of_tweets |> Enum.each(fn _x ->User.tweet(state[:username], "password", getRandomMessage(hash_tags, no_of_users)) end)
  #   # GenServer.call(:twitter_engine, {:processed?})
  #   # 1..no_of_retweets |> Enum.each(fn _x -> retweet(state[:username], "password", Enum.random(1..no_of_users)) end)
  #   {:noreply, state}
  # end

  def getRandomMessage(hash_tags, no_of_users) do

    "random tweet #{UUID.uuid1()} @#{Enum.random(1..no_of_users)} @#{Enum.random(1..no_of_users)} #{Enum.random(hash_tags)} #{Enum.random(hash_tags)}"
  end

end
