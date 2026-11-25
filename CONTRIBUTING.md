# Contributing

Thank you for your help with the Snapsbrew Ruby gem.

## Report a bug or ask for a feature

Open an issue with the bug template or the feature template. If the problem is about security, do not open an issue. Read [SECURITY.md](SECURITY.md).

## Prepare your environment

1. Install Ruby 3.2 or later.
2. Clone the repository.
3. Run `bundle install`.
4. Run `bin/rake`. All tests must pass before you change the code.

## Make a change

1. Make a branch from `main`.
2. Write a test that shows the bug or the new behavior. Make sure that the test fails.
3. Change the code until the test passes.
4. Run `bin/rake`, `bin/rubocop` and `bin/rake rbs`.
5. If you change the public API, update `sig/snapsbrew.rbs`, `README.md` and `CHANGELOG.md`.
6. Open a pull request and complete the template.

## Rules for the code

- Use the Ruby standard library. Do not add a runtime dependency.
- Use Minitest for the tests. Do not make real HTTP requests in the unit tests. Use WebMock.
- Follow the RuboCop rules of `rubocop-rails-omakase`.
- Do not add telemetry.
- Never put a token, a signing key or another secret in the code, the tests or the logs.

## Rules for the text

Write the docs, the comments and the commit messages in Simplified Technical English:

- Use short sentences. A procedure step has 20 words or fewer. A description has 25 words or fewer.
- Use the active voice. Use the imperative for instructions.
- Use one word for one meaning.
- Do not use contractions or semicolons.

## Test with a different Rails version

Set `RAILS_VERSION` and update the bundle:

```sh
RAILS_VERSION="~> 7.2.0" bundle update rails
bin/rake test:rails
```

## Run the integration tests

The integration tests use a real Snapsbrew instance. They read the account and the templates, and they make one free preview.

```sh
SNAPSBREW_TEST_URL=https://snaps.example.com SNAPSBREW_TEST_TOKEN=your-token bin/rake test:integration
```

## Pull request titles

The title of a pull request must follow [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/). The `PR title` check of the CI fails if the title does not follow it. The titles of the merged pull requests become the lines of the release notes, so a clear title helps each user.

Start the title with a type: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore` or `revert`. A scope in parentheses is optional. Examples:

- `feat: add a method to cancel a snap batch`
- `fix(rails): read the instance URL from the credentials`
- `docs: add a webhook example to the README`

## Triage

Each new issue gets the `needs-triage` label. The maintainer reads the issue and replaces `needs-triage` with a type label, for example `bug`, `enhancement`, `documentation` or `question`.
