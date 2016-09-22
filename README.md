# PR Stats


## Installation

Copy `env.example` to `.env` and customise the values as needed.

You need a github API key and a repository name in `owner/repo` format.

## Deployment

Deploy to Heroku.

[![Deploy](https://www.herokucdn.com/deploy/button.svg)](https://heroku.com/deploy)

You will need to provide the following details.

```
GITHUB_API_TOKEN
```
The Authentication Token for the GitHub API

```
GITHUB_TARGET_REPO
```
The repository you want to watch.
It needs to be in 'owner/repository' format e.g.
`garrow/prstats`

```
GITHUB_WATCH_LABEL
```
A label which marks your outstanding pull requests, e.g. 'Needs Review'"

## Authentication


You can use a personal access token from
https://github.com/settings/tokens
Create a token, and give it access to the following scopes

- `repo`
- `repo:status`
    - `repo_deployment`
    - `public_repo`
- `admin:repo_hook`
    - `write:repo_hook`
    - `read:repo_hook`
