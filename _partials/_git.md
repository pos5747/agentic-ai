### Git, GitHub, and GitHub Desktop

**Install git.** **On macOS**, run `xcode-select --install` in the terminal and click *Install* in the window that opens. (If it says the tools are already installed, you're done.) **On Windows**, download [Git for Windows](https://git-scm.com/downloads/win), run the installer, and accept the default on every screen. Then restart the terminal.

**Test git.** Run `git --version`. Make sure it prints a version number (e.g., `git version 2.39.5`).

**Register a GitHub account.** If you don't already have one, sign up at [github.com](https://github.com) with your .edu e-mail address. (You can add other e-mail addresses later.)

**Introduce yourself to git.** (Only do this on your personal computer.) Run the two commands below, using your own name and the e-mail address associated with your GitHub account.

```sh
git config --global user.name "Jane Doe"
git config --global user.email "jdoe@fsu.edu"
```

Run `git config --global --list` and make sure it shows your name and e-mail.

**Install GitHub Desktop.** Download [GitHub Desktop](https://desktop.github.com), install it, and open it. Sign in with your GitHub account when it asks.

**Test GitHub Desktop.** **On macOS**, click *GitHub Desktop* > *Settings...* > *Accounts*. **On Windows**, click *File* > *Options* > *Accounts*. Make sure your GitHub username appears. If so, you've got git and GitHub Desktop working.

An agent can change many files at once. Git records every version of your files, so you can see exactly what the agent changed and undo it.
