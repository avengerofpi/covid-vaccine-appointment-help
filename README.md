# Giant Foods Covid-19 Vaccination Appointment Discovery Notification Script

## Summary
The Bash script `checkGiantSignup.sh` queries the Giant Foods vaccine website
and inspects the response to check for an indication that appointments are (or
"might be") available. On such a response, the script sends out email
notifications to a distro defined in the file `distro.config`. The user will
need to create and populate this distro file as it is not included in the repo.
We leave it out of the repo because we want to make it difficult to
accidentally share one's distro. We provide a sample distro file with fake
email addresses in `distro.sample.config`. Copy and customize this.

The script is setup to be gentle on the Giant Foods website. It is currently
coded to query at most every 60 seconds. If a response indicates that
appointments might be available, a longer delay occurs before the next query
(currently 20 minutes + the estimated "wait in line" time, if this wait time
could be parsed from the response).

The script uses `ssmtp` to send the email notifications, and you will need to
configure that so you can dispatch emails through whatever email account you so
choose. A thorough discussion of how to do this is beyond the scope of this
README, but the internet has documentation.

The script does nothing deeper in the Giant Foods website than attempt to
detect whether appointments might be available. The notifications are sent to
prompt the distro recipients to go to the Giant Foods website themselves, get
"in line," and (if lucky) make it to the page where they can query zip codes
looking for a Giant Foods location with appointment times available. The
notifications are just to keep the user from having to refresh the Giant Foods
website manually.

## Config and execution
* Create and customize the `distro.config` file (copy from `distro.sample.config`).
* Configure `ssmtp` so you can dispatch emails with it.
* The Bash script is already shebanged and executable.

## Handling other types of responses
The script explicitly handles two other types of response --- "no appointments
available" responses and "the service is down" responses. In both cases,
nothing special is done, just capturing some relevant text and logging it to
stdout. This logging actually occurs regardless of the response, just that the
text for each type of response is empty when the current response is not of
that type (the XPaths we use to extract the text for each type of response are
currently strong enough to ensure this, at least).

Sample responses for the known types are available in `response-samples/`.

If an unexpected response occurs, one where we don't find any text in the
expected XPath locations, the script saves off a copy of that response in the
`response-samples/` directory, tagged with a timestamp in its name (both to
make it easy to know when that response occurred and to avoid filename
collisions).
