# Frinkiac for Slack

A simple app that lets you pull Simpsons screencaps from <a href="https://frinkiac.com/">Frinkiac</a> in Slack! Just use the <code>/frink</code> command, followed by a quote from The Simpsons.

![](http://i.imgur.com/IT32eMF.jpg)

## Installation

If you just want to install the `/frink` command in your Slack, go to [the website](https://slashfrink.herokuapp.com/) and hit the "Add to Slack" button to authorize the app.

If you'd rather host it yourself in your own Heroku account, follow these steps:

1. Create a [new Slack app](https://api.slack.com/applications/new) for your team (put a placeholder redirect URI for now, like `http://localhost` or whatever).
2. Add a new command to your new Slack app, like `/frink`. Note your app's client ID, client secret, and the verification token for the command.
3. Come back here and push this button to create a new Heroku app: [![Deploy](https://www.herokucdn.com/deploy/button.png)](https://heroku.com/deploy)
4. In your new Heroku app's config variables, enter the client ID, client secret, and verification token from step 2.
5. Deploy your Heroku app, and note its address (should be `https://[your heroku app].herokuapp.com`).
6. Come back to your Slack app, and replace the redirect URI with `https://[your heroku app].herokuapp.com/auth`.
7. Visit `https://[your heroku app].herokuapp.com` in your browser and use the "Add to Slack" button to add your app to your Slack team.
