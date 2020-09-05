defmodule AccountManagerTest do
  use ExUnit.Case
  # doctest Example
  setup_all do
    start_supervised!(MainSupervisor)
    {:ok, username: UUID.uuid1()}
  end


  test "register new user(feature testing)", state do
    username = state[:username]
    AccountManager.register_account(username,"bhaskar")
    # {:ok, state_after_execution} = :sys.get_state(:account_manager)
    GenServer.call(:account_manager, {:processed?})
    usernames = :ets.lookup(:users, username) |> Enum.map(fn {x,_y} -> x end)
    inserted? = Enum.member?(usernames, username)
    assert  inserted? == true
  end

  test "check user exists(single function testing)" do
    new_user1 = UUID.uuid1()
    new_user2 = UUID.uuid1()
    :ets.insert(:users,{new_user1, "password"})
    assert  AccountManager.user_exists?(new_user1) == true
    assert  AccountManager.user_exists?(new_user2) == false
  end

  test "delete user(feature testing)" do
    user1 = UUID.uuid1()
    user2 = UUID.uuid1()
    user3 = UUID.uuid1()

    AccountManager.register_account(user1,"password")
    AccountManager.register_account(user2,"password")
    AccountManager.register_account(user3,"password")

    User.login(user1, "password")
    User.login(user2, "password")
    User.login(user3, "password")

    User.subscribe_to_user(user3, "password", user1)
    User.subscribe_to_user(user2, "password", user1)
    User.subscribe_to_user(user1, "password", user2)
    User.subscribe_to_user(user1, "password", user2)
    User.subscribe_to_user(user3, "password", user2)

    GenServer.call(:account_manager, {:processed?})

    message1 = "Let's go to football @#{user2} @#{user3} #gators #football"
    message2 = "The football match was good @#{user1} @#{user2} #football"
    message3 = "we shall now study"

    User.tweet(user1,"password", message1)
    User.tweet(user3,"password", message2)
    User.retweet(user2,"password", user1)
    User.tweet(user1,"password", message3)

    GenServer.call(:twitter_engine, {:processed?})

    AccountManager.delete_account(user1, "password")
    GenServer.call(:account_manager, {:processed?})
    assert AccountManager.user_exists?(user1) == false

    football_tweets = User.query_tweets(user2, "password", :get_hash_tagged_tweets, "football")
    gators_tweets = User.query_tweets(user2, "password",:get_hash_tagged_tweets, "gators")
    user1_feed = User.query_tweets(user2, "password",:get_subscribed_tweets, user1)
    # user2_feed = User.query_tweets(user2, "password",:get_subscribed_tweets, user2)
    user3_feed = User.query_tweets(user2, "password",:get_subscribed_tweets, user2)

    user1_mentioned_tweets = User.query_tweets(user2, "password",:get_mentioned_tweets, user1)

    # IO.puts("user10 mentioned tweets = #{inspect user10_mentioned_tweets}")

    assert Enum.member?(football_tweets, message1) == false
    assert Enum.member?(gators_tweets, message1) == false
    assert Enum.member?(football_tweets, message2) == true
    # IO.puts("user11 feed is #{inspect user11_feed}")

    assert user1_feed == []
    assert user1_mentioned_tweets == []

    assert Enum.member?(user3_feed, message2) == false;
    # assert Enum.member?(user2_feed, message2) == false;

    # assert Enum.member?(user2_feed, message3) == true
    # assert Enum.member?(user11_feed, message1) == false
    # assert Enum.member?(user10_mentioned_tweets, message1) == true
    # assert Enum.member?(user10_mentioned_tweets, message2) == true
    # assert Enum.member?(user10_mentioned_tweets, message3) == false

  end




end
