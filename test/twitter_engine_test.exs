defmodule TwitterEngineTest do
  use ExUnit.Case
  # doctest Example
  setup_all do
    start_supervised!(MainSupervisor)
    # user1 = UUID.uuid1()
    # user2 = UUID.uuid1()
    # user3 = UUID.uuid1()
    # user4 = UUID.uuid1()
    # user5 = UUID.uuid1()
    user1 = "user1"
    user2 = "user2"
    user3 = "user3"
    user4 = "user4"
    user5 = "user5"

    AccountManager.register_account(user1,"password")
    AccountManager.register_account(user2,"password")
    AccountManager.register_account(user3,"password")
    AccountManager.register_account(user4,"password")
    AccountManager.register_account(user5,"password")

    GenServer.call(:account_manager, {:processed?})

    User.login(user1, "password")
    User.login(user2, "password")
    User.login(user3, "password")
    User.login(user4, "password")

    GenServer.call(RegistryHelper.get_user_pid(user1), {:processed?})
    GenServer.call(RegistryHelper.get_user_pid(user2), {:processed?})
    GenServer.call(RegistryHelper.get_user_pid(user3), {:processed?})
    GenServer.call(RegistryHelper.get_user_pid(user4), {:processed?})

    User.subscribe_to_user(user2, "password", user1)
    User.subscribe_to_user(user3, "password", user1)
    User.subscribe_to_user(user4, "password", user1)
    User.logout(user4, "password")
    GenServer.call(:account_manager, {:processed?})
    GenServer.call(:twitter_engine, {:processed?})

    GenServer.call(RegistryHelper.get_user_pid(user1), {:processed?})
    GenServer.call(RegistryHelper.get_user_pid(user2), {:processed?})
    GenServer.call(RegistryHelper.get_user_pid(user3), {:processed?})
    # GenServer.call(RegistryHelper.get_user_pid(user4), {:processed?})

    {:ok, user1: user1, user2: user2, user3: user3, user4: user4, user5: user5}
  end

  # user1 is followed by user2, user3, user4
  test "distribute tweets to alive users(single function testing)", state  do
    User.login(state[:user5], "password")
    message = "Hello world from user1 @#{state[:user5]} @#{state[:user2]}"
    TwitterEngine.distribute_tweets([state[:user2], state[:user3], state[:user4], state[:user5]], message)

    GenServer.call(:twitter_engine, {:processed?})
    GenServer.call(:account_manager, {:processed?})
    pid = RegistryHelper.get_user_pid(state[:user3]);
    GenServer.call(pid, {:processed?})
    pid = RegistryHelper.get_user_pid(state[:user5]);
    GenServer.call(pid, {:processed?})

    notifications2 = User.get_notifications(state[:user2])
    notifications3 = User.get_notifications(state[:user3])
    notifications4 = User.get_notifications(state[:user4])
    notifications5 = User.get_notifications(state[:user5])

    assert notifications4 == []
    assert List.first(notifications2) == message
    assert List.first(notifications3) == message
    assert List.first(notifications5) == message

  end


  test "get followers(single function testing)", state do
    user1_followers  = TwitterEngine.get_followers(state[:user1])
    assert true = Enum.member?(user1_followers,"user2")
    assert true = Enum.member?(user1_followers,"user3")
    assert true = Enum.member?(user1_followers,"user4")
  end


  test "check processing tweet(single function testing)", state do
    message = "Second tweet from user1 #DOS #Sai #Raghu @#{state[:user5]}  @#{state[:user3]}"
    tweet_id = User.tweet(state[:user1], "password",  message)
    GenServer.call(:twitter_engine, {:processed?})

    mentioned_tweet_ids_1 =     :ets.match(:mentions, {"#{state[:user3]}",:"$1"}) |> Enum.map(fn [x] -> x end)
    mentioned_tweet_ids_2 =     :ets.match(:mentions, {"#{state[:user5]}",:"$1"}) |> Enum.map(fn [x] -> x end)

    hash_tags_1 =     :ets.match(:hash_tags, {"DOS",:"$1"}) |> Enum.map(fn [x] -> x end)
    hash_tags_2 =     :ets.match(:hash_tags, {"Sai",:"$1"}) |> Enum.map(fn [x] -> x end)
    hash_tags_3 =     :ets.match(:hash_tags, {"Raghu",:"$1"}) |> Enum.map(fn [x] -> x end)

    assert Enum.member?(mentioned_tweet_ids_1, tweet_id) && Enum.member?(mentioned_tweet_ids_2, tweet_id) == true
    assert Enum.member?(hash_tags_1, tweet_id) && Enum.member?(hash_tags_2, tweet_id)  && Enum.member?(hash_tags_3, tweet_id) == true

  end


end
