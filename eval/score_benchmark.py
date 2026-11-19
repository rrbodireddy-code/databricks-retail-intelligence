"""Deterministic numeric scorer for the retail Genie benchmark.

Phase 8, ticket P8-1. Scores an answer by checking whether each expected
value from the hand verified ground truth actually appears in the answer,
within tolerance. No language model involved, so the score is repeatable.

Also verifies the dataset against itself (cross-checks) and self-tests the
scorer with a perfect answer and a wrong answer. The self-test is scorer
validation only, it is not a Genie result. Real Genie answers get scored in
Databricks by 07_mlflow_genai_evaluation.py, which imports this logic.
"""
import json
import re
import sys

NUMBER_RE = re.compile(r"\d{1,3}(?:,\d{3})+(?:\.\d+)?|\d+\.\d+|\d+")


def extract_numbers(text):
    """Pull every number out of an answer, commas removed."""
    if text is None:
        return []
    out = []
    for m in NUMBER_RE.finditer(str(text)):
        try:
            out.append(float(m.group(0).replace(",", "")))
        except ValueError:
            pass
    return out


def _within(value, expected, spec):
    if "tol_abs" in spec:
        return abs(value - expected) <= spec["tol_abs"]
    tol = spec.get("tol_rel", 0.001) * abs(expected)
    return abs(value - expected) <= tol


def score_answer(item, answer_text):
    """Return (score, details). Score is matched checks / total checks."""
    numbers = extract_numbers(answer_text)
    details = []
    matched = 0
    checks = 0
    for spec in item.get("expected_numbers", []):
        checks += 1
        expected = spec["value"]
        hit = any(_within(n, expected, spec) for n in numbers)
        details.append(
            {"label": spec["label"], "expected": expected, "matched": hit}
        )
        if hit:
            matched += 1
    lowered = (answer_text or "").lower()
    for s in item.get("expected_strings", []):
        checks += 1
        hit = s.lower() in lowered
        details.append({"label": "string:" + s, "expected": s, "matched": hit})
        if hit:
            matched += 1
    score = (matched / checks) if checks else 0.0
    return score, details


def cross_checks(dataset):
    """The ground truth must reconcile with itself, like the Gold tables did."""
    items = {i["id"]: i for i in dataset["items"]}

    def val(item_id, label):
        for spec in items[item_id]["expected_numbers"]:
            if spec["label"] == label:
                return spec["value"]
        raise KeyError(label)

    results = []
    gross_total = val(2, "gross_store") + val(2, "gross_catalog") + val(2, "gross_web")
    results.append(
        ("gross by channel sums to 60,023,366,486.73",
         abs(gross_total - 60023366486.73) < 0.01)
    )
    net_total = val(3, "net_store") + val(3, "net_catalog") + val(3, "net_web")
    results.append(
        ("net by channel sums to total net (Q1)",
         abs(net_total - val(1, "total_net_sales")) < 0.01)
    )
    for ch in ["store", "catalog", "web"]:
        lhs = val(2, "gross_" + ch) - val(5, "returns_" + ch)
        rhs = val(3, "net_" + ch)
        results.append((f"gross minus returns equals net, {ch}",
                        abs(lhs - rhs) < 0.01))
    ret_total = (val(5, "returns_store") + val(5, "returns_catalog")
                 + val(5, "returns_web"))
    results.append(
        ("gross total minus returns total equals net total",
         abs(gross_total - ret_total - val(1, "total_net_sales")) < 0.01)
    )
    return results


def main():
    path = sys.argv[1] if len(sys.argv) > 1 else "benchmark_dataset.json"
    with open(path) as f:
        dataset = json.load(f)

    print("== Cross-checks on the ground truth itself ==")
    ok = True
    for name, passed in cross_checks(dataset):
        print(("PASS" if passed else "FAIL"), "-", name)
        ok = ok and passed

    print()
    print("== Scorer self-test (validation only, not a Genie result) ==")
    perfect_all = True
    for item in dataset["items"]:
        score, _ = score_answer(item, item["expected_text"])
        print(f"Q{item['id']}: exact answer scores {score:.2f}")
        perfect_all = perfect_all and score == 1.0
    wrong = "The total was 1,000. Store was 2,000, catalog 3,000, web 4,000."
    bad_scores = [score_answer(i, wrong)[0] for i in dataset["items"]]
    print("Wrong answer scores per question:", [round(s, 2) for s in bad_scores])
    wrong_ok = all(s < 1.0 for s in bad_scores)
    print()
    print("Self-test:", "PASS" if (perfect_all and wrong_ok) else "FAIL")
    print("Cross-checks:", "PASS" if ok else "FAIL")


if __name__ == "__main__":
    main()
