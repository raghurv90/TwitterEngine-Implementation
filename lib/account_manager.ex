defmodule AccountManager do
  use GenServer

  def start_link(_account_manager_number) do
    GenServer.start_link(__MODULE__, [] ,name: :account_manager )
  end

  def init(_init_arg) do
    {:ok, MapSet.new()}
  end

  def register_account(username, password) do
    GenServer.cast(:account_manager, {:register_account, username, password})
  end

  defp add_account_if_new(username, password, state) do
    if ( !user_exists?(username)) do
      # IO.puts("adding user #{username}")
      :ets.insert(:users, {username, password})
    end
    {:noreply, state}
  end

  def user_exists?(username) do
    not(:ets.lookup(:users, username) |> Enum.empty?)
  end

  def delete_account(username, password) do
    GenServer.cast(:account_manager, {:delete_account, username, password})
  end

  def delete_account_if_exists(username, password, state) do
    if ( user_exists?(username)) do
      User.logout(username, password)
      :ets.delete(:users, username)
      :ets.match_delete(:subscriptions, {username, :_})
      :ets.match_delete(:subscriptions, {:_, username})
      :ets.match_delete(:tweets, {:_, username, :_, :_})
      :ets.match_delete(:retweets, {:_, username, :_, :_, :_})
      :ets.match_delete(:retweets, {:_, :_, :_, username, :_})
      :ets.match_delete(:mentions, {username, :_})

      # {tweet_id, _username, message, tweet_time} tweets
      # {retweet_id, username, celebrity_last_tweet_id, celebrity_name, retweet_time}
      # delete from all the other tables
    end
    {:noreply, state}
  end

  def subscribe_to_user(username, celebrity_name) do
    GenServer.cast(:account_manager, {:subscribe_to_user, username, celebrity_name})
  end

  def handle_cast({:subscribe_to_user, username, celebrity_name}, state) do
    not_subscribed = Enum.empty?(:ets.lookup(:subscriptions, {username, celebrity_name}))
    if(not_subscribed) do
      :ets.insert(:subscriptions, {username, celebrity_name})
      # IO.puts("after inserting")
    end
    {:noreply, state}
  end

  def handle_cast({create_or_delete_account, username, password}, state) do
    case create_or_delete_account do
      :delete_account -> delete_account_if_exists(username, password, state)
      :register_account -> add_account_if_new(username, password, state)
    end
  end

  def handle_call({:processed?}, _from, state) do
		{:reply, true, state}
	end


end
