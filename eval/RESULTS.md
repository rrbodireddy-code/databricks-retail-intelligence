# MLflow evaluation of the Genie agent

After the manual check in Phase 6, I wanted a check I could re-run. A single
manual pass tells me the agent was right that day. It does not tell me if it
stays right. So I put the same questions into MLflow GenAI evaluation
(notebook `07_mlflow_genai_evaluation.py` in this folder) and ran them
against the live agent three times on 19 Nov 2026. Experiment:
retail_genie_eval, in my own workspace.

## What gets scored

12 questions: the 10 benchmark questions from Phase 6, with the same
hand-verified answers, plus the 2 trap tests (March 2002 must be refused;
"sales" with nothing else must come back as net sales, stated as net).

Two scorers look at every answer:

- `numeric_match`, a scorer I wrote. It pulls the numbers out of the
  agent's answer text and compares them with the expected values, allowing
  small rounding differences. It also checks for phrases the answer must
  contain. It gives full, half or no credit per question.
- `Correctness`, MLflow's LLM judge (Llama 3.3 70B on Databricks). It reads
  the question, the expected answer and the agent's answer, and says yes or
  no.

## The three runs

Run 1: numeric_match 0.833. The judge produced no scores at all, because my
evaluation data was missing the field the judge needs (`expected_response`).
That was my formatting mistake, not an agent problem.

Run 2: the judge worked and scored 0.75. The numeric scorer crashed on 11
of the 12 rows because of an indentation mistake in my notebook copy, so
its headline mean of 1.0 covered a single row. I only caught that by
reading the results table. A headline number on its own is not a result.

Run 3 was the first clean run: **numeric_match 0.917, Correctness 0.833**,
both scorers scoring all 12 rows.

## What run 3 found

The numeric scorer gave 10 rows full credit and 2 rows half credit. The
judge failed the same 2 rows and passed the other 10.

- Return rates by channel (half credit): the answer text names only
  catalog, the highest rate at 9.77%. The store and web rates are not in
  the text the agent returned.
- Best sales day (half credit): the agent names the right day, 2002-01-02,
  with the wrong value, 7,016,246,497.10. The correct value is
  10,595,422,126.45.

Both trap tests passed both scorers in run 3.

## The finding that matters

The best-day answer was wrong in all three runs, with the same wrong value
every time. In Phase 6 I ran that question once, by hand, and marked it
correct. Run once, it looked fine. Run three times under a scorer, it is
wrong every time. That is the reason this folder exists: repeated checks
catch what a single pass misses.

## Limits I know about

- The harness reads the agent's text answer only. If the agent puts figures
  in a result table and does not repeat them in the text, the numeric
  scorer cannot see them. The return-rate row may partly be this.
- The judge can change its mind on borderline rows. It failed the
  net-default trap in run 2 and passed it in run 3, on answers that both
  defaulted to net sales. I still review disagreements myself against the
  hand-verified answers, and the hand-verified answers win.

## Files in this folder

- `07_mlflow_genai_evaluation.py` — the evaluation notebook (Databricks
  source format).
- `benchmark_dataset.json` — the 12 questions with the expected values.
- `score_benchmark.py` — a standalone copy of the numeric scorer, with a
  self-test, that runs outside Databricks.
- `RESULTS.md` — this file.
