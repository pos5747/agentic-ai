# Build img/results-by-prompt.png, the deck's "Fully correct, by prompt" chart,
# from the four graded z batches (the 2026-10-20/22 re-run on y ~ x + z) in
# ../../local-agent-example/results/.
# A run is fully correct when its stage is S6 (tools/RUBRIC.md), the same
# count as the Totals slide and the appendix tables.
#
# usage, from site/slides/:  Rscript src/results-chart.R

library(tidyverse)

results <- "../../local-agent-example/results"

batches <- c(
  "z-haiku"  = "Haiku",
  "z-sonnet" = "Sonnet",
  "z-qwen"   = "qwen",
  "z-gptoss" = "gpt-oss"
)

prompts <- tribble(
  ~key,           ~task,          ~prompt,
  "print-naive",  "Summarize",    "naive",
  "print-better", "Summarize",    "better",
  "bugs-naive",   "Find",         "naive",
  "bugs-better",  "Find",         "better",
  "fix-vague",    "Fix",          "vague",
  "fix-naive",    "Fix",          "naive",
  "fix-better",   "Fix",          "better",
  "fix-scope",    "Fix",          "scoped",
  "prob-naive",   "Probability",  "naive",
  "prob-better",  "Probability",  "better",
  "ci-naive",     "CI",           "naive",
  "ci-better",    "CI",           "better",
  "iqr-naive",    "IQR effect",   "naive",
  "iqr-base",     "IQR effect",   "better",
  "iqr-fn",       "IQR effect",   "+ fn"
) |>
  mutate(
    task = fct_inorder(task),
    prompt_id = fct_inorder(paste(task, prompt))
  )

runs <- imap(batches, \(label, batch) {
  read_csv(file.path(results, batch, "runs.csv"), col_types = cols(.default = "c")) |>
    mutate(model = label)
}) |>
  list_rbind()

shares <- runs |>
  group_by(model, key) |>
  summarize(n = n(), correct = sum(stage == "S6"), .groups = "drop") |>
  mutate(pct = 100 * correct / n) |>
  inner_join(prompts, by = "key") |>
  mutate(model = factor(model, levels = unname(batches)))

stopifnot(nrow(shares) == 60, all(shares$n == 10))

colors <- c(
  "Haiku"   = "#f59e0b",
  "Sonnet"  = "#b45309",
  "qwen"    = "#2563eb",
  "gpt-oss" = "#0f766e"
)

dodge <- position_dodge(width = 0.45)

p <- ggplot(shares, aes(x = prompt_id, y = pct, color = model, group = model)) +
  geom_line(position = dodge, linewidth = 1.1, alpha = 0.85) +
  geom_point(position = dodge, size = 3.4) +
  facet_grid(. ~ task, scales = "free_x", space = "free_x") +
  scale_x_discrete(labels = \(x) sub("^.* (naive|better|vague|scoped|\\+ fn)$", "\\1", x)) +
  scale_y_continuous(
    limits = c(-3, 103), breaks = c(0, 25, 50, 75, 100),
    labels = \(x) paste0(x, "%"), expand = expansion(0)
  ) +
  scale_color_manual(values = colors, name = NULL) +
  labs(x = NULL, y = "fully correct") +
  theme_minimal(base_family = "Source Sans 3", base_size = 17) +
  theme(
    text = element_text(color = "#1f2933"),
    axis.text = element_text(color = "#3e4c59"),
    axis.text.x = element_text(size = 13),
    strip.text = element_text(face = "bold", size = 17, hjust = 0),
    panel.grid.major.x = element_blank(),
    panel.grid.minor = element_blank(),
    panel.grid.major.y = element_line(color = "#e4e7eb"),
    panel.spacing.x = unit(1.4, "lines"),
    legend.position = "top",
    legend.justification = "left",
    legend.text = element_text(size = 16),
    legend.key.width = unit(1.6, "lines"),
    plot.margin = margin(4, 8, 4, 4)
  )

ggsave("img/results-by-prompt.png", p,
  width = 11.8, height = 4.6, dpi = 200, device = ragg::agg_png, bg = "white"
)
