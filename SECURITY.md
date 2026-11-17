# Security policy

## Report a security problem

Do not report a security problem in a public issue, a pull request or a discussion.

Report it in private through a GitHub security advisory:

1. Go to the **Security** tab of this repository.
2. Click **Report a vulnerability**.
3. Write what you found, the steps to see the problem, and the versions of the gem, Ruby and Rails.

We reply to each report. When the fix is ready, we publish the advisory and a new version.

## Supported versions

Only the latest version of the gem gets security fixes.

## Secrets

The API token and the signing key are secrets. Keep them in Rails credentials or in environment variables. Do not put them in an issue, a log or the code. Build signed URLs on the server only.
