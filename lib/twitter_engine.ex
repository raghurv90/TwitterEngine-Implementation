defmodule TwitterEngine do

  use GenServer

  def start_link(_engine_number) do
      GenServer.start_link(__MODULE__, [] ,name: :twitter_engine )
  end

  def init(_init_arg) do


    # users : username to password
    # tweets :  tweet_id, username, message, tweet_time
    # mentions : mentioned_username to tweetIDs # take care to put mention only once even if mentioned twice
    # hash_tags : hash_tags to tweetIDs
    # retweets : retweet_id , username , tweetIDs, retweet_time # can retweet more than once
    # subscriptions: username to celebrity_ids


    :ets.new(:users, [:set, :public, :named_table])
    :ets.new(:tweets, [:set, :public, :named_table])
    :ets.new(:mentions, [:bag, :public, :named_table])
    :ets.new(:hash_tags, [:bag, :public, :named_table])
    :ets.new(:retweets, [:bag, :public, :named_table])
    :ets.new(:subscriptions, [:bag, :public, :named_table]) #done inserting into table, need to implement unsubscribe
    {:ok, []}
  end

  def check_authentication(_username, _password) do
    true
  end

  def process_message(username, tweet_id, message) do
    GenServer.cast(:twitter_engine, {:process_tweet, username, tweet_id, message})
  end

  def get_usernames_list() do
    :ets.match(:users, {:"$1",:_}) |>Enum.map(fn [x] -> x end)
  end

  def handle_cast({:process_tweet, username, tweet_id, message}, state) do
    usernames = get_usernames_list()

    mentions_and_hashes = message
                |> String.replace("#"," #") |> String.replace("@", " @")
                |> String.split()
                |> Enum.filter(fn x-> String.at(x,0) == "@" || String.at(x, 0)=="#" end)
                |> Enum.filter(fn x -> String.length(x) > 1 end)

    mentions = mentions_and_hashes
                |> Enum.filter(fn x -> String.at(x, 0) == "@" end)
                |> Enum.map( fn x -> String.replace(x,"@","") end)
                |> Enum.uniq()
                |> Enum.filter(fn x -> Enum.member?(usernames, x) end)

    hash_tags = mentions_and_hashes
                |> Enum.filter(fn x -> String.at(x, 0) == "#" end)
                |> Enum.map( fn x -> String.replace(x,"#","") end)
                |> Enum.uniq()

    mentions  |> Enum.each(fn user -> :ets.insert(:mentions, {user, tweet_id}) end)
    hash_tags |> Enum.each(fn tag -> :ets.insert(:hash_tags, {tag, tweet_id}) end)

    followers = get_followers(username)
    users_tweet_to_be_distributed = (followers ++ mentions) |> Enum.uniq()
    distribute_tweets(users_tweet_to_be_distributed, message)
    {:noreply, state}
  end

  def distribute_tweets(users_tweet_to_be_distributed, message) do
    # followers = get_followers(username)
    # IO.puts("followers of #{username} are #{inspect followers}")
    users_tweet_to_be_distributed   |> Enum.map(fn x-> User.get_pid_if_alive(x) end)
                                    |> Enum.filter(fn x-> (x != nil) end)
                                    |> Enum.each(fn x-> send_tweet_notification(x, message) end)
  end

  def distribute_retweet(username, message) do
    GenServer.cast(:twitter_engine,{:distribute_retweet, username, message})
  end

  def handle_cast({:distribute_retweet, username, message}, state) do
    followers = get_followers(username)
    distribute_tweets(followers, message)
    {:noreply, state}
  end

  def send_tweet_notification(alive_follower_pid, message) do
    GenServer.cast(alive_follower_pid, {:send_tweet_notification, message})
  end


  def get_followers(username) do
    :ets.match(:subscriptions, {:"$1", username}) |> Enum.map(fn [x] -> x end)
  end

  def handle_call({:processed?}, _from, state) do
		{:reply, true, state}
	end


end
