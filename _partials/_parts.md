### Part 1: Find and fix the bugs

Prompts 1–4 ask a question about the script. They don't ask the agent to
change a file. Prompts 5 and 6 ask the agent to change `logit.R`.

**Prompt 1.**

> Describe what logit.R does.

**Prompt 2.**

> Review the code in logit.R and tell me what it does, step by step. Don't assume the code matches the comments. Don't change anything yet.

**Prompt 3.**

> Find all bugs in logit.R.

**Prompt 4.**

> Find all the bugs in logit.R, including any that give a wrong answer without an error. Run it to check. Don't fix anything yet; just list the bugs and explain each one.

**Prompt 5.**

> Fix all bugs in logit.R.

**Prompt 6.**

> Find and fix all the bugs in logit.R, including any that give a wrong answer without an error. Run it to check.

**Check the agent's work.** After prompts 5 and 6, check the fix before you
discard it.

- In the *Changes* tab, look at which files changed. Then look at which lines
  of `logit.R` changed.
- In RStudio, click *Source* to run the agent's version of the script. The
  script is supposed to print a probability. Is the number it prints between
  0 and 1?

#### Fix the script yourself and commit it

Parts 2 and 3 use a script without the bugs. So after you've discarded the
changes from prompt 6, fix the two bugs by hand. In RStudio, change `binomal`
to `binomial` on line 4, and add `type = "response"` to `predict()` on line 7.
The script should now read

```r
# fit a logit model and report one predicted probability
dat <- read.csv("data.csv")

fit <- glm(y ~ x + z, family = binomial, data = dat)

# predicted probability that y = 1 when x = 1 and z = 0
pr <- predict(fit, newdata = data.frame(x = 1, z = 0), type = "response")
print(pr)
```

Save the file and click *Source*. You should see

```
        1 
0.8492817 
```

Now commit the fix. In GitHub Desktop, the *Changes* tab should list
`logit.R`, with two changed lines. Make sure `logit.R` is the only file with a
check mark. Type `Fix the two bugs` in the *Summary* box and click *Commit to
main*. (In the terminal, `git commit -am "Fix the two bugs"` does the same
thing.)

The commit adds your fixed script to git's record. The *Changes* tab is empty
again, and from here on, *Discard All Changes...* puts the folder back to the
fixed script.

### Part 2: Run and extend the code

Prompts 7–9 ask for a number. They don't ask the agent to change a file.
Prompt 10 asks the agent to change `logit.R`.

**Prompt 7.**

> What's the predicted probability that y = 1 when x = 1 and z = 0?

**Prompt 8.**

> Use logit.R to compute the predicted probability that y = 1 when x = 1 and z = 0. Run the code and show me what it prints.

**Prompt 9.**

> What's the 95% confidence interval for the predicted probability that y = 1 when x = 1 and z = 0?

**Prompt 10.**

> Modify logit.R to also compute a 95% confidence interval for the predicted probability that y = 1 when x = 1 and z = 0. Tell me how the interval is computed, run the code, and show me what it prints.

**Check the agent's work.** Before you discard the changes from prompt 10,
click *Source* in RStudio to see what the agent's script prints. After you've
discarded the changes, compute the numbers yourself. In the RStudio console,
run

```r
dat <- read.csv("data.csv")
fit <- glm(y ~ x + z, family = binomial, data = dat)

# the predicted probability, from the coefficients
plogis(sum(coef(fit) * c(1, 1, 0)))

# a 95% interval computed on the log-odds scale, then transformed
p <- predict(fit, newdata = data.frame(x = 1, z = 0), se.fit = TRUE)
plogis(p$fit + c(-1.96, 1.96) * p$se.fit)

# a 95% interval computed on the probability scale (the delta method)
r <- predict(fit, newdata = data.frame(x = 1, z = 0), type = "response", se.fit = TRUE)
r$fit + c(-1.96, 1.96) * r$se.fit
```

Does the agent's probability match yours? Which of the two intervals matches
the agent's interval? Is that the method the agent said it used?

### Part 3: Write new code

These three prompts ask for a quantity the script doesn't compute. Prompt 11
doesn't name a file. Prompts 12 and 13 ask the agent to change `logit.R`.

**Prompt 11.**

> Use {marginaleffects} to find the average difference in the probability that y = 1 when x moves from its 25th to its 75th percentile, averaged across the observed values in the data, and its 95% confidence interval.

**Prompt 12.**

> Change logit.R so it uses {marginaleffects} to report the average difference in the probability that y = 1 when x moves from its 25th to its 75th percentile, averaged across the observed values in the data, with a 95% confidence interval. Before you write any code, read the {marginaleffects} documentation and look at its examples. Then run logit.R and show me what it prints.

**Prompt 13.**

> Change logit.R so it uses avg_comparisons() from {marginaleffects} to report the average difference in the probability that y = 1 when x moves from its 25th to its 75th percentile, averaged across the observed values in the data, with a 95% confidence interval. Before you write any code, read the help page for avg_comparisons() and look at its examples. Then run logit.R and show me what it prints.

**Check the agent's work.** Before you discard the changes from prompts 12
and 13, click *Source* in RStudio to see what the agent's script prints. After
you've discarded the changes, compute the average difference yourself. With
`dat` and `fit` from Part 2, run

```r
q <- quantile(dat$x, c(0.25, 0.75))
p75 <- predict(fit, newdata = transform(dat, x = q[2]), type = "response")
p25 <- predict(fit, newdata = transform(dat, x = q[1]), type = "response")
mean(p75 - p25)
```

Does the agent's number match yours?

