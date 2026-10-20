### The answers

Check these only after you've run the prompts.

<details>
<summary>Show the answers</summary>

**Part 1**

- **The two bugs.** Line 4 misspells `binomial` as `binomal`, so `glm()`
  fails. Line 7 calls `predict()` without `type = "response"`, so once the
  typo is fixed, the script prints the log-odds (1.729) rather than a
  probability.
- **Prompts 1 and 2** should say what the script does: it reads `data.csv`,
  fits a logit model of `y` on `x` and `z`, and prints a prediction for
  `x = 1` and `z = 0`. A complete answer also names both bugs. An answer that says the script prints
  a probability is wrong. No file should change.
- **Prompts 3 and 4** should list both bugs and nothing else. (A missing
  `data.csv` and points of style aren't bugs in this script.) `logit.R` and
  `data.csv` should be unchanged. A new file (e.g., a test script) is a change
  you didn't ask for, so write it down.
- **Prompts 5 and 6** should leave a `logit.R` that prints 0.849, with changes
  on lines 4 and 7 only. `data.csv` should be unchanged. If the script prints
  1.729, then the agent fixed only the typo.

**Part 2**

- **Prompts 7–10.** The predicted probability is 0.849.
- **Prompts 9 and 10.** The 95% interval is (0.776, 0.901) if it's computed on
  the log-odds scale and then transformed, or (0.787, 0.911) if it's computed
  on the probability scale (the delta method). Both are defensible. The method
  the agent names should be the method its code uses. An interval of (0.776,
  0.901) is not the delta method. An interval near (0.72, 0.93) is wrong. It
  comes from transforming the endpoints of the coefficients' confidence
  intervals: (0.718, 0.926) from `confint.default()` or (0.723, 0.928) from
  `confint()`.
- **Prompts 7–9** shouldn't change a file. **Prompt 10** should add the
  interval to `logit.R` and keep the lines that print the probability.

**Part 3**

- **Prompts 11–13.** The average difference is 0.433, with a 95% interval of
  (0.375, 0.491). The call is `avg_comparisons(fit, variables = list(x =
  "iqr"))`.
- **Wrong answers to recognize.** 0.253 is the average slope (from
  `avg_slopes()`). 0.254 is the difference for a one-unit change in `x` (the
  default of `avg_comparisons()`). 0.345 is the difference for a
  one-standard-deviation change. 0.180 compares `x = 0.25` with `x = 0.75`.
  0.611 is the difference with `z` held at its mean, rather than averaged
  across the observed values.
- **Prompt 11** shouldn't change a file. **Prompts 12 and 13** should change
  `logit.R` only.

</details>

