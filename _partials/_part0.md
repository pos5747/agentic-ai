### Part 0: Clone the script and the data

The script and its data are in a GitHub repository,
[pos5747/agentic-ai-example](https://github.com/pos5747/agentic-ai-example).
It has three files: `logit.R`, `data.csv` (which the script reads), and
`agentic-ai-example.Rproj` (an RStudio project file).

**Clone the repository.** In GitHub Desktop, click *File* > *Clone
Repository...* and click the *URL* tab. Type `pos5747/agentic-ai-example` in
the first box. The *Local Path* box shows the folder the files will go in
(usually `Documents/GitHub/agentic-ai-example`). Click *Clone*. (In the
terminal, `git clone https://github.com/pos5747/agentic-ai-example.git` does
the same thing. It puts the folder inside the folder you run it from.)

Cloning copies the files to your computer, along with git's record of
them. Because git has that record, GitHub Desktop can show you every change an
agent makes to the folder, and it can undo the changes.

**Open the project and run the script.** In RStudio, click *File* > *Open
Project...* and open `agentic-ai-example.Rproj` from the folder. (Opening the
project sets R's working directory to the folder, so R finds `data.csv`.) In
the *Files* pane, click `logit.R` to open it. Then click *Source*. You should
see an error that ends in `object 'binomal' not found`.

Keep `logit.R` open in RStudio. When an agent changes the file, RStudio shows
the new version, and you can click *Source* to run it. Don't edit the file
while an agent is running.

**Commit the `.gitignore` file.** When RStudio opens the project, it adds two
things to the folder. The first is a hidden folder named `.Rproj.user`, where
RStudio keeps its own settings for the project. The second is a file named
`.gitignore`, which tells git to leave that folder (and R's `.RData` and
`.Rhistory` files) out of its record. In GitHub Desktop, click the *Changes*
tab. It lists `.gitignore` as a new file. Make sure `.gitignore` is the only
file with a check mark. Type `Add .gitignore` in the *Summary* box and click
*Commit to main*. The *Changes* tab is now empty. (If the tab was already
empty, skip this step.)

A commit adds the current version of the checked files to git's record. You
don't need to click *Push origin*. Your commits stay on your computer.

**Move the terminal into the folder.** The agents work in the folder you start
them from. In the terminal, run

```sh
cd ~/Documents/GitHub/agentic-ai-example
```

(If your *Local Path* was a different folder, use that folder in the `cd`
command, here and below.)

**Look at what the agent changed, then undo it.** The agents sometimes edit
the script, change the data, or create new files, even when you only ask a
question. After each prompt, open GitHub Desktop and click the *Changes* tab.
It lists every file the agent changed or created. Click a file to see the
lines that changed. Write down which files changed. Then click *Branch* >
*Discard All Changes...* to undo the changes. If the *Changes* tab lists no
files, then the agent changed nothing, and there's nothing to discard.

On a Mac, a file named `.DS_Store` sometimes appears in the list. Finder
creates it when you open the folder, so it isn't the agent's work. Don't write
it down. You can discard it with the other changes.

If you prefer the terminal, `git status` lists the files that changed, `git
diff` shows the lines (press `q` to leave a long one), and these two commands
undo the changes:

```sh
git restore .
git clean -fd
```

(The terminal version of the `.gitignore` commit is `git add .gitignore`, then
`git commit -m "Add .gitignore"`.)
