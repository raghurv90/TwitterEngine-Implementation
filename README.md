# TwitterEngine-Implementation

The goal of this project is to implement a Twitter-like engine provide following functionalities.

- Register account
- Send tweet. Tweets can have hashtags (e.g. #COP5615isgreat) and mentions (@bestuser)
- Subscribe to user's tweets
- Re-tweets (so that your subscribers get an interesting tweet you got by other means)
- Allow querying tweets subscribed to, tweets with specific hashtags, tweets in which the user is mentioned (my mentions)
- If the user is connected, deliver the above types of tweets live (without querying)


Twitter Design and implemented functionality:

- We have one GenServer which is responsible for managing accounts(registering and deleting).
-	We have one twitter engine responsible for distribution of tweets
-	We have one GenServer per each logged in User. If a user is live a corresponding GenServer is made alive and it is terminated when the user logs out. (This way it’s practical to use as not all the users would be logged in at the same time thereby decreasing the load.)

We have the following tables:
1.	:users -> :set   => {usernames, passwords}
2.	:tweets -> :set => {tweet_id, username, message, tweet_time}
3.	:mentions -> :bag =>{mentioned_username, tweetID}
4.	:hash_tags -> :bag => {hash_tags, tweetId}
5.	:retweets -> :bag => {retweet_id , username , tweetIDs, retweet_time}
6.	:subscriptions -> :bag => {follower_id, user_subscribed_to(like celebrity)}
Note: the code and the tables have password for future extensibility and the authentication isn’t done for this version.

A user needs to be registered and logged in before he can do anything (else the required action isn’t performed). An entry is made in :users table when a user is registered. 
When he tweets an entry is made into the tweets table by the User GenServer. A message is sent to the Engine to distribute tweets. It processes the tweet makes entry into hash_tags, mentions tables, and then sends notifications to mentioned users and followers if they’re alive.
A user can retweet any other user’s last made tweet(need not be subscribed to that user). We cannot retweet a retweet. Any entry is made in the retweets table and notification is sent to the alive followers. The mentions don’t get notifications as it’s a retweet.
A user can subscribe to another user, entry is made in the subscriptions table.
An alive User can query for his feed(tweets  of all he is subscribed to)(he receives both tweets and retweets, but only once if there’s a same message from both) , tweets that any user is mentioned(need not be himself), a particular hash_tag.
A user can be deleted, then all the corresponding entries of that user would be deleted from all the tables.

Testing:
Exunit tests are written to test both whole feature testing and individual function testing(like checking logged in or checking tweet distribution). Most tests have both positive and negative tests. Note: as individual functions are tested separately they are directly used while testing the feautures.

The following exunits test the whole features:
1.	register new user(feature testing) : It is tested whether an entry is made in the users table.
2.	login and logout user(feature testing) :Various users are logged in and logged out and seen the if the corresponding states are reflected correctly. (Logged in users have a corresponding alive Genserver, and hence an entry in the registry)
3.	tweeting(feature testing) : We have users, who are subscribed to some users. Some users are logged in. Some of the alive users tweet messages with mentions and hashtags. It is checked whether all the alive users got notifications if they’re either the followers or if they’re mentioned. Negative tests are done in the sense those who shouldn’t receive notifications are not receiving any.
4.	retweeting(feature testing):
We have users, who are subscribed to some users. Some users are logged in. Some of the alive users tweet messages with mentions and hashtags. Some other users retweet, we check whether the alive followers of the retweeter get notifications.
5.	Querying(feature testing): 
We have users, who are subscribed to some users. Some users are logged in. Some of the alive users tweet messages with mentions and hashtags. Some users also retweet. We then query for various users, various hash tags and mentions. This test essentially has the major part of the other tests in it as well, as getting the correct querry result implies the tweet is also made properly
6.	delete user(feature testing): This tests whether the all the entries corresponding user are deleted from all the tables present.

Tests that test individual functionality:
1.	check processing tweet(single function testing) : This tests whether the tweet message is processed correctly to check for hashtags, mentions and entries are made into right ets tables.
2.	 get followers(single function testing) : tests if we are getting the followers of a user correctly
3.	distribute tweets to alive users(single function testing): This tests whether the engine is distributing the tweet(notification) to the required followers and mentions correctly
4.	check user exists(single function testing) : checks if there’s a user with the given name

