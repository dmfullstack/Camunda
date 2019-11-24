package org.camunda.bpm.example.twitter;

import org.camunda.bpm.engine.delegate.DelegateExecution;
import org.camunda.bpm.engine.delegate.JavaDelegate;

import twitter4j.Twitter;
import twitter4j.TwitterFactory;
import twitter4j.auth.AccessToken;

/**
 * Publish content on Twitter. It really goes live! Watch out http://twitter.com/#!/camunda_demo for your postings.
 */
public class TweetContentDelegate implements JavaDelegate {

  public void execute(DelegateExecution execution) throws Exception {      
    Tweet tweet = (Tweet) execution.getVariable("tweet");
      
    AccessToken accessToken = new AccessToken("220324559-jet1dkzhSOeDWdaclI48z5txJRFLCnLOK45qStvo", "B28Ze8VDucBdiE38aVQqTxOyPc7eHunxBVv7XgGim4say");
    Twitter twitter = new TwitterFactory().getInstance();
    twitter.setOAuthConsumer("lRhS80iIXXQtm6LM03awjvrvk", "gabtxwW8lnSL9yQUNdzAfgBOgIMSRqh7MegQs79GlKVWF36qLS");
    twitter.setOAuthAccessToken(accessToken);    
    
    twitter.updateStatus(tweet.getContent());
  }

}
