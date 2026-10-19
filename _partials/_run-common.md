**Write down what the agent said, not what it should have said.** In lecture,
we looked at many runs of the same prompt. Compare the run you got with those. (Those runs
approved every request ahead of time.)

**`data.csv` has 500 rows plus a header.** An agent sometimes reports that
`data.csv` is truncated. It isn't. To check, run `nrow(read.csv("data.csv"))`
in the RStudio console. It prints `500`.
