# Strap
Strap is a script to bootstrap a minimal macOS development system. This is a minimal version of Mike McQuaid's original tool, which does only the bare minimum necessary to clone and run your dotfiles repo. It's expected that any further customization needed, will be taken care of by your dotfiles setup.

## Features
- Installs the Xcode Command Line Tools (to get a working version of git)
- Installs dotfiles from a user's `https://github.com/username/dotfiles` repository and runs `script/setup` to configure them.
- A simple web application to set Git's name, email and GitHub token (needs to be authorized on any organizations you wish to access)
- Mostly idempotent (the slow bit is rerunning `brew update`)

## Usage
Open https://get-strap.herokuapp.com in your web browser.

Alternatively, to run Strap locally run:
```bash
git clone https://github.com/jd20/strap
cd strap
bash bin/strap.sh # or bash bin/strap.sh --debug for more debugging output
```

Alternatively, to run the web application locally run:
```bash
git clone https://github.com/jd20/strap
cd strap
GITHUB_KEY="..." GITHUB_SECRET="..." ./script/server
```

Alternatively, to deploy to [Heroku](https://www.heroku.com) click:

[![Deploy to Heroku](https://www.herokucdn.com/deploy/button.svg)](https://heroku.com/deploy)

## Web Application Configuration Environment Variables
- `GITHUB_KEY`: the GitHub.com Application Client ID..
- `GITHUB_SECRET`: the GitHub.com Application Client Secret..
- `SESSION_SECRET`: the secret used for cookie session storage.
- `WEB_CONCURRENCY`: the number of Unicorn (web server) processes to run (defaults to 3).
- `STRAP_ISSUES_URL`: the URL where users should file issues (defaults to https://github.com/jd20/strap/issues/new).
- `STRAP_BEFORE_INSTALL`: instructions displayed in the web application for users to follow before installing Strap (will be wrapped in `<li>` tags).

## Status
Stable and in active development.

[![Build Status](https://travis-ci.org/jd20/strap.svg)](https://travis-ci.org/jd20/strap)

## License
Strap is licensed under the [MIT License](http://en.wikipedia.org/wiki/MIT_License).
The full license text is available in [LICENSE.txt](https://github.com/mikemcquaid/strap/blob/master/LICENSE.txt).
