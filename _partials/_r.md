### R and {marginaleffects}

**Install (or update) R and RStudio.** You should already have these from this course.

**Install the marginaleffects package.** In RStudio, click the *Packages* tab in the lower-right pane, click *Install*, type "marginaleffects," and click *Install*.

**Let the terminal find R (Windows only).** The agent runs R from the terminal, and on Windows, the terminal can't find R until you add it to your PATH. In PowerShell, run

```powershell
$rbin = (Get-ChildItem "C:\Program Files\R" | Sort-Object Name | Select-Object -Last 1).FullName + "\bin"
[Environment]::SetEnvironmentVariable("Path", [Environment]::GetEnvironmentVariable("Path", "User") + ";$rbin", "User")
```

and then restart the terminal.

**Test R from the terminal.** Run

```sh
Rscript -e "library(marginaleffects); cat('ok')"
```

Make sure it prints `ok`. If so, the agent can run R.
