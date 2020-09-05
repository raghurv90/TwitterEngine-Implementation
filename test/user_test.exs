defmodule UserTest do

  use ExUnit.Case

# once see async tests

  setup_all do
    start_supervised!(MainSupervisor)
    user1 = UUID.uuid1()
    user2 = UUID.uuid1()
    user3 = UUID.uuid1()
    user4 = UUID.uuid1()
    user5 = UUID.uuid1()
    user6 = UUID.uuid1()
    user7 = UUID.uuid1()

    AccountManager.register_account(user1,"password")
    AccountManager.register_account(user2,"password")
    AccountManager.register_account(user3,"password")
    AccountManager.register_account(user4,"password")
    AccountManager.register_account(user5,"password")
    AccountManager.register_account(user6,"password")
    AccountManager.register_account(user7,"password")

    GenServer.call(:account_manager, {:processed?})
    User.login(user3, "password")
    User.login(user5, "password")
    User.login(user6, "password")
    User.login(user7, "password")

    User.subscribe_to_user(user5, "password", user2)
    User.subscribe_to_user(user3, "password", user2)
    User.subscribe_to_user(user6, "password", user4)
    User.subscribe_to_user(user7, "password", user4)

    User.logout(user3, "password")
    User.logout(user5, "password")
    User.logout(user6, "password")
    User.logout(user7, "password")

    {:ok, user1: user1, user2: user2, user3: user3, user4: user4, user5: user5, user6: user6, user7: user7 }
  end





  test "login and logout user(feature testing)", state do
    username = state[:user1]
    GenServer.call(:account_manager, {:processed?})
    User.login(username,"password")
    GenServer.call(:account_manager, {:processed?})
    assert User.check_logged_in?(username, "password") == true;
    User.login(username,"password") #trying to login an already logged in user
    assert User.check_logged_in?(username, "password") == true;
    assert User.check_logged_in?(UUID.uuid1(), "password") == false; #checking a non user
    User.logout(username, "password")
    assert User.check_logged_in?(username, "password") == false
    temp_uuid = UUID.uuid1()
    User.logout(temp_uuid, "password")
    assert User.check_logged_in?(temp_uuid, "password") ==false;
  end

  test "subscriptions(feature testing)", state do
    username = state[:user1]
    User.login(username, "password1")
    temp_celebrity = UUID.uuid1()
    User.subscribe_to_user(username, "password1", temp_celebrity)
    inserted? = not(Enum.empty?(:ets.match_object(:subscriptions, {username, temp_celebrity})))
    assert inserted? == false
    AccountManager.register_account(temp_celebrity, "password2")
    GenServer.call(:account_manager, {:processed?})
    pid = RegistryHelper.get_user_pid(username);
    GenServer.call(pid, {:processed?})
    User.subscribe_to_user(username, "password1", temp_celebrity)

    GenServer.call(pid, {:processed?})
    GenServer.call(:account_manager, {:processed?})
    GenServer.call(pid, {:processed?})
    inserted? = not(Enum.empty?(:ets.match_object(:subscriptions, {username, temp_celebrity})))
    assert inserted? == true
  end


  # user3 and user5 are subscribed to user2
  test "tweeting(feature testing)", state do
    User.login(state[:user2], "password")
    User.logout(state[:user5], "password")
    User.login(state[:user3], "password")
    User.login(state[:user4], "password")
    User.logout(state[:user1], "password")

    message = "This is awesome #UF #Gainesville @#{state[:user4]} @#{state[:user1]} "
    tweet_id = User.tweet(state[:user2], "password", message)

    tweet = :ets.match(:tweets, {tweet_id, :_, :"$1", :_}) |> Enum.map(fn [x] -> x end) |> Enum.at(0)
    GenServer.call(:account_manager, {:processed?})
    GenServer.call(:twitter_engine, {:processed?})

    notifications1 = User.get_notifications(state[:user1])
    notifications3 = User.get_notifications(state[:user3])
    notifications4 = User.get_notifications(state[:user4])
    notifications5 = User.get_notifications(state[:user5])

    assert tweet == message
    assert List.first(notifications3) == message
    assert List.first(notifications4) == message

    assert notifications5 == []
    assert notifications1 == []

  end


# user6 and user7 are subscribed to user4 (user6 will be alive while user 7 is logged out)
#user1 tweets three messages and user4 retweets the last message  of user1
  test "retweeting(feature testing)", state do
    User.login(state[:user6], "password")
    User.login(state[:user1], "password")
    User.login(state[:user4], "password")

    User.logout(state[:user7], "password")
    message = "The project looks good #DOS #Masters @#{state[:user4]} @#{state[:user2]} "
    _tweet_id = User.tweet(state[:user1], "password", message)
    retweet_id = User.retweet(state[:user4], "password", state[:user1])

    GenServer.call(:account_manager, {:processed?})
    GenServer.call(:twitter_engine, {:processed?})

    tweet_id_from_retweet = :ets.match(:retweets, {retweet_id, state[:user4], :"$1", :_, :_})
                            |> Enum.map(fn[x] -> x end) |> Enum.at(0)
    message_from_retweet =  :ets.match(:tweets, {tweet_id_from_retweet, :_, :"$1", :_})
                            |> Enum.map(fn [x] -> x end) |> Enum.at(0)

    notifications6 = User.get_notifications(state[:user6])
    notifications7 = User.get_notifications(state[:user7])

    assert message_from_retweet == message
    assert List.first(notifications6) == message
    assert notifications7 == []
  end


  test "querying the tweets(feature testing)" do
    user8 = UUID.uuid1()
    user9 = UUID.uuid1()
    user10 = UUID.uuid1()
    user11 = UUID.uuid1()
    user12 = UUID.uuid1()
    user13 = UUID.uuid1()

    # user8 = "user8"
    # user9 = "user9"
    # user10 ="user10"
    # user11 = "user11"
    # user12 = "user12"
    # user13 = "user13"

    AccountManager.register_account(user8,"password")
    AccountManager.register_account(user9,"password")
    AccountManager.register_account(user10,"password")
    AccountManager.register_account(user11,"password")
    AccountManager.register_account(user12,"password")
    AccountManager.register_account(user13,"password")
    User.login(user8, "password")
    User.login(user9, "password")
    User.login(user10, "password")
    User.login(user11, "password")
    User.login(user12, "password")

    User.subscribe_to_user(user9, "password", user8)
    User.subscribe_to_user(user10, "password", user8)
    User.subscribe_to_user(user11, "password", user9)
    User.subscribe_to_user(user12, "password", user8)
    User.subscribe_to_user(user12, "password", user9)
    GenServer.call(:account_manager, {:processed?})

    message1 = "Let's go to football @#{user10} @#{user13} #gators #football"
    message2 = "The football match was good @#{user10} @#{user13} #football"
    message3 = "we shall now study"

    User.tweet(user8,"password", message1)
    User.tweet(user8,"password", message2)
    User.retweet(user9,"password", user8)
    User.tweet(user9,"password", message3)

    GenServer.call(:twitter_engine, {:processed?})

    # :get_subscribed_tweets -> get_subscribed_tweets(query_parameter)
    # :get_hash_tagged_tweets -> get_hash_tagged_tweets(query_parameter)
    # :get_mentioned_tweets -> get_mentioned_tweets(query_parameter)

    football_tweets = User.query_tweets(user8, "password", :get_hash_tagged_tweets, "football")
    gators_tweets = User.query_tweets(user8, "password",:get_hash_tagged_tweets, "gators")
    user11_feed = User.query_tweets(user11, "password",:get_subscribed_tweets, user11)
    user10_mentioned_tweets = User.query_tweets(user10, "password",:get_mentioned_tweets, user10)

    # IO.puts("user10 mentioned tweets = #{inspect user10_mentioned_tweets}")

    assert Enum.member?(football_tweets, message1) == true
    assert Enum.member?(football_tweets, message2) == true
    assert Enum.member?(gators_tweets, message1) == true
    assert Enum.member?(gators_tweets, message2) == false
    # IO.puts("user11 feed is #{inspect user11_feed}")
    assert Enum.member?(user11_feed, message2) == true
    assert Enum.member?(user11_feed, message3) == true
    assert Enum.member?(user11_feed, message1) == false
    assert Enum.member?(user10_mentioned_tweets, message1) == true
    assert Enum.member?(user10_mentioned_tweets, message2) == true
    assert Enum.member?(user10_mentioned_tweets, message3) == false


  end










end
