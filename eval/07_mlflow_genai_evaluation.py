# Databricks notebook source
# Notebook 07_mlflow_genai_evaluation (Phase 8, tickets P8-2 and P8-3)
# Purpose: evaluate the live Retail Genie agent with MLflow GenAI evaluation:
# a deterministic numeric scorer (custom) plus MLflow Correctness (LLM judge),
# against the hand verified 10 question benchmark from notebook 06_evaluation.
# Ground truth wins over any judge disagreement, same rule as Phase 6.

# COMMAND ----------

# MAGIC %pip install -U "mlflow>=3.1" databricks-sdk
# MAGIC %restart_python

# COMMAND ----------

import json
import re

import mlflow
from databricks.sdk import WorkspaceClient

GENIE_SPACE_ID = "01f1e23a46481afa913829f8d5a6f969"
JUDGE_MODEL = "databricks:/databricks-meta-llama-3-3-70b-instruct"

mlflow.set_experiment("/Workspace/Demo_Project/retail_genie_eval")

# COMMAND ----------

# The benchmark dataset, identical to benchmark_dataset.json in the project
# files. Expected values come only from the hand verified ground truth.
BENCHMARK = [
    {"id": 1, "question": "What were total net sales?",
     "expected_text": "54,892,741,614.60",
     "expected_numbers": [{"label": "total_net_sales", "value": 54892741614.60, "tol_rel": 0.001}],
     "expected_strings": []},
    {"id": 2, "question": "What were total gross sales by channel?",
     "expected_text": "store 32,347,398,464.95; catalog 16,128,618,826.98; web 11,547,349,194.80",
     "expected_numbers": [
         {"label": "gross_store", "value": 32347398464.95, "tol_rel": 0.001},
         {"label": "gross_catalog", "value": 16128618826.98, "tol_rel": 0.001},
         {"label": "gross_web", "value": 11547349194.80, "tol_rel": 0.001}],
     "expected_strings": []},
    {"id": 3, "question": "What were total net sales by channel?",
     "expected_text": "store 29,407,210,700.90; catalog 14,553,183,186.55; web 10,932,347,727.15",
     "expected_numbers": [
         {"label": "net_store", "value": 29407210700.90, "tol_rel": 0.001},
         {"label": "net_catalog", "value": 14553183186.55, "tol_rel": 0.001},
         {"label": "net_web", "value": 10932347727.15, "tol_rel": 0.001}],
     "expected_strings": []},
    {"id": 4, "question": "Which channel had the highest return rate?",
     "expected_text": "catalog, about 9.8% (store 9.1%, web 5.3%)",
     "expected_numbers": [
         {"label": "return_rate_catalog_pct", "value": 9.8, "tol_abs": 0.35},
         {"label": "return_rate_store_pct", "value": 9.1, "tol_abs": 0.35},
         {"label": "return_rate_web_pct", "value": 5.3, "tol_abs": 0.35}],
     "expected_strings": ["catalog"]},
    {"id": 5, "question": "What were total returns by channel?",
     "expected_text": "store 2,940,187,764.05; catalog 1,575,435,640.43; web 615,001,467.65",
     "expected_numbers": [
         {"label": "returns_store", "value": 2940187764.05, "tol_rel": 0.001},
         {"label": "returns_catalog", "value": 1575435640.43, "tol_rel": 0.001},
         {"label": "returns_web", "value": 615001467.65, "tol_rel": 0.001}],
     "expected_strings": []},
    {"id": 6, "question": "What are the top 5 products by gross sales?",
     "expected_text": "614,998.15; 612,099.09; 611,790.10; 604,566.28; 599,087.30",
     "expected_numbers": [
         {"label": "top1", "value": 614998.15, "tol_rel": 0.001},
         {"label": "top2", "value": 612099.09, "tol_rel": 0.001},
         {"label": "top3", "value": 611790.10, "tol_rel": 0.001},
         {"label": "top4", "value": 604566.28, "tol_rel": 0.001},
         {"label": "top5", "value": 599087.30, "tol_rel": 0.001}],
     "expected_strings": []},
    {"id": 7, "question": "How many orders were there in total?",
     "expected_text": "2,598,807",
     "expected_numbers": [{"label": "total_orders", "value": 2598807, "tol_rel": 0.001}],
     "expected_strings": []},
    {"id": 8, "question": "Which day had the highest net sales?",
     "expected_text": "2002-01-02, 10,595,422,126.45",
     "expected_numbers": [{"label": "best_day_net", "value": 10595422126.45, "tol_rel": 0.001}],
     "expected_strings": ["2002-01-02"]},
    {"id": 9, "question": "What were net sales for the web channel on January 6, 2002?",
     "expected_text": "534,821,677.60",
     "expected_numbers": [{"label": "web_net_2002_01_06", "value": 534821677.60, "tol_rel": 0.001}],
     "expected_strings": []},
    {"id": 10, "question": "How many units were returned by channel?",
     "expected_text": "store 77,574,820; catalog 31,089,323; web 12,198,373",
     "expected_numbers": [
         {"label": "units_returned_store", "value": 77574820, "tol_rel": 0.001},
         {"label": "units_returned_catalog", "value": 31089323, "tol_rel": 0.001},
         {"label": "units_returned_web", "value": 12198373, "tol_rel": 0.001}],
     "expected_strings": []},
]

TRAP_TESTS = [
    {"id": "T1", "question": "What were total net sales in March 2002?",
     "expected_text": "The agent must refuse or state the data only covers January 1 to 14, 2002. It must not give a March sales number.",
     "expected_numbers": [], "expected_strings": [],
     "any_strings": ["out of scope", "only covers", "no information",
                     "not available", "no data"],
     "forbid_big_number": True},
    {"id": "T2", "question": "What were sales?",
     "expected_text": "The agent must default to net sales and say that it is reporting net sales. Expected total net sales value is 54,892,741,614.60.",
     "expected_numbers": [{"label": "total_net_sales", "value": 54892741614.60, "tol_rel": 0.001}],
     "expected_strings": ["net"]},
]

BY_QUESTION = {b["question"]: b for b in BENCHMARK + TRAP_TESTS}
print("benchmark rows:", len(BENCHMARK), "| trap rows:", len(TRAP_TESTS))

# COMMAND ----------

# Predict step: ask the LIVE Genie agent, one fresh conversation per question.
w = WorkspaceClient()


def ask_genie(question: str) -> str:
    msg = w.genie.start_conversation_and_wait(
        space_id=GENIE_SPACE_ID, content=question
    )
    parts = []
    for att in (msg.attachments or []):
        if getattr(att, "text", None) and att.text.content:
            parts.append(att.text.content)
    return "\n".join(parts) if parts else (msg.content or "")


# Quick smoke test on one question before the full run.
print(ask_genie(BENCHMARK[0]["question"])[:500])

# COMMAND ----------

# Custom deterministic scorer: same logic as score_benchmark.py (P8-1).
NUMBER_RE = re.compile(r"\d{1,3}(?:,\d{3})+(?:\.\d+)?|\d+\.\d+|\d+")


def extract_numbers(text):
    out = []
    for m in NUMBER_RE.finditer(str(text or "")):
        try:
            out.append(float(m.group(0).replace(",", "")))
        except ValueError:
            pass
    return out


from mlflow.entities import Feedback
from mlflow.genai.scorers import scorer


@scorer
def numeric_match(inputs, outputs, expectations):
    item = BY_QUESTION[inputs["question"]]
    numbers = extract_numbers(outputs)
    details, matched, checks = [], 0, 0
    for spec in item["expected_numbers"]:
        checks += 1
        expected = spec["value"]
        if "tol_abs" in spec:
            hit = any(abs(n - expected) <= spec["tol_abs"] for n in numbers)
        else:
            tol = spec.get("tol_rel", 0.001) * abs(expected)
            hit = any(abs(n - expected) <= tol for n in numbers)
        details.append(f"{spec['label']}={'ok' if hit else 'MISS'}")
        matched += 1 if hit else 0
    lowered = str(outputs or "").lower()
    for s in item["expected_strings"]:
        checks += 1
        hit = s.lower() in lowered
        details.append(f"string:{s}={'ok' if hit else 'MISS'}")
        matched += 1 if hit else 0
    if item.get("any_strings"):
        checks += 1
        hit = any(s.lower() in lowered for s in item["any_strings"])
        details.append(f"any_string={'ok' if hit else 'MISS'}")
        matched += 1 if hit else 0
    if item.get("forbid_big_number"):
        checks += 1
        hit = not any(n >= 1_000_000 for n in numbers)
        details.append(f"no_big_number={'ok' if hit else 'MISS'}")
        matched += 1 if hit else 0
    value = (matched / checks) if checks else 0.0
    return Feedback(
        name="numeric_match", value=value, rationale="; ".join(details)
    )


# COMMAND ----------

# Evaluation data in MLflow format. Expectations carry the verified answer
# text so the Correctness judge scores against ground truth, not opinion.
eval_data = [
    {
        "inputs": {"question": b["question"]},
        "expectations": {
            "expected_answer": b["expected_text"],
            # MLflow's Correctness judge requires expected_response
            # (or expected_facts) inside expectations.
            "expected_response": b["expected_text"],
        },
    }
    for b in BENCHMARK + TRAP_TESTS
]


def predict_fn(question: str) -> str:
    return ask_genie(question)


# COMMAND ----------

# Run the evaluation. If the judge model is not available in this workspace,
# the run still works with the numeric scorer alone: remove Correctness from
# the list, rerun, and note the judge as blocked in the run description.
from mlflow.genai.scorers import Correctness

try:
    judge_scorer = Correctness(model=JUDGE_MODEL)
except Exception:
    judge_scorer = Correctness()

with mlflow.start_run(run_name="genie_eval_phase8"):
    results = mlflow.genai.evaluate(
        data=eval_data,
        predict_fn=predict_fn,
        scorers=[numeric_match, judge_scorer],
    )

print(results.metrics)
# Table keys differ across MLflow versions: display whatever came back.
for _key, _table in results.tables.items():
    print("table:", _key)
    display(_table)

