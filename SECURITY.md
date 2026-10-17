# Security

Please report a vulnerability in Relay, its installer or anything in this repository privately, not in a public issue.

- Use GitHub's private reporting: **Security → Report a vulnerability** on this repository, or write to the Relay founders at arnav@relayevals.com.
- Include what you found, how to reproduce it, and the Relay version (`relay --version`).

We will reply as soon as we can. Please give us a reasonable time to fix the problem before you disclose it.

## The installer

`install.sh` downloads a versioned release from relayevals.com and checks every file against the release's `SHA256SUMS` before it installs anything. The copy in this repository is the one `https://relayevals.com/install.sh` serves; a daily check compares the two.
