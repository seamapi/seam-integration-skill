#!/usr/bin/env python3
"""
Rubric checker (Layer 1) — scores a skill-modified fixture against its answer key.

Usage:
    python rubric_checker.py --pristine <dir> --modified <dir> --fixture-dir <dir>
"""

import argparse
import filecmp
import json
import os
import re
import sys


# ---------------------------------------------------------------------------
# Config loading
# ---------------------------------------------------------------------------

def load_config(fixture_dir):
    """Load answer_key.json, eval_config.json from fixture_dir, and rubric.json from evals/."""
    evals_dir = os.path.dirname(os.path.abspath(__file__))

    with open(os.path.join(fixture_dir, "answer_key.json")) as f:
        answer_key = json.load(f)
    with open(os.path.join(fixture_dir, "eval_config.json")) as f:
        eval_config = json.load(f)
    with open(os.path.join(evals_dir, "rubric.json")) as f:
        rubric = json.load(f)

    return answer_key, eval_config, rubric


# ---------------------------------------------------------------------------
# Diff computation
# ---------------------------------------------------------------------------

def compute_diff(pristine_dir, modified_dir):
    """Return dict of changed_files and new_files (relative paths). No git dependency."""
    changed_files = []
    new_files = []

    # Gather all files in modified dir
    modified_files = set()
    for root, _dirs, files in os.walk(modified_dir):
        # Skip node_modules and dist
        rel_root = os.path.relpath(root, modified_dir)
        if any(part in ("node_modules", "dist", ".git") for part in rel_root.split(os.sep)):
            continue
        for f in files:
            rel = os.path.relpath(os.path.join(root, f), modified_dir)
            modified_files.add(rel)

    # Gather all files in pristine dir
    pristine_files = set()
    for root, _dirs, files in os.walk(pristine_dir):
        rel_root = os.path.relpath(root, pristine_dir)
        if any(part in ("node_modules", "dist", ".git") for part in rel_root.split(os.sep)):
            continue
        for f in files:
            rel = os.path.relpath(os.path.join(root, f), pristine_dir)
            pristine_files.add(rel)

    # New files: in modified but not in pristine
    for rel in sorted(modified_files - pristine_files):
        new_files.append(rel)

    # Changed files: in both but content differs
    for rel in sorted(modified_files & pristine_files):
        p = os.path.join(pristine_dir, rel)
        m = os.path.join(modified_dir, rel)
        if not filecmp.cmp(p, m, shallow=False):
            changed_files.append(rel)

    return {"changed_files": changed_files, "new_files": new_files}


# ---------------------------------------------------------------------------
# File reading
# ---------------------------------------------------------------------------

def read_modified_files(modified_dir, file_list):
    """Read full content of files, returns dict {relative_path: content}."""
    result = {}
    for rel in file_list:
        path = os.path.join(modified_dir, rel)
        try:
            with open(path, "r", errors="replace") as f:
                result[rel] = f.read()
        except (OSError, IOError):
            pass
    return result


# ---------------------------------------------------------------------------
# Check functions (each returns 0.0 - 1.0)
# ---------------------------------------------------------------------------

def check_api_path_match(modified_files_content, eval_config):
    """Check that the expected API path signature is found and wrong ones aren't."""
    # Each path maps to multiple signatures (snake_case REST + camelCase SDK)
    path_signatures = {
        "reservation_automations": ["push_data", "pushData"],
        "access_grants": ["access_grants.create", "accessGrants.create"],
        "lower_level": ["access_codes.create", "accessCodes.create"],
    }

    expected_path = eval_config.get("expected_api_path", "")
    expected_sigs = path_signatures.get(expected_path, [])
    if not expected_sigs:
        return 0.0

    all_content = "\n".join(modified_files_content.values())

    found_expected = any(sig in all_content for sig in expected_sigs)

    # Check for wrong signatures
    wrong_sigs = []
    for path, sigs in path_signatures.items():
        if path != expected_path:
            wrong_sigs.extend(sigs)
    found_wrong = any(sig in all_content for sig in wrong_sigs)

    if found_expected and not found_wrong:
        return 1.0
    elif found_expected and found_wrong:
        return 0.5
    else:
        return 0.0


def check_files_modified_match(changed_files, new_files, answer_key):
    """Proportion of expected_files_modified actually modified, minus unexpected new files."""
    expected_modified = answer_key.get("expected_files_modified", [])
    expected_new_allowed = answer_key.get("expected_new_files_allowed", [])

    if not expected_modified:
        return 1.0

    # Score for expected modifications
    hit_count = sum(1 for f in expected_modified if f in changed_files)
    mod_score = hit_count / len(expected_modified)

    # Deduction for unexpected new files
    unexpected_new = [f for f in new_files if f not in expected_new_allowed]
    if new_files:
        deduction = len(unexpected_new) / max(len(new_files), 1) * 0.3
    else:
        deduction = 0.0

    return max(0.0, min(1.0, mod_score - deduction))


def check_calls_in_expected_functions(modified_files_content, answer_key):
    """Check that SDK calls appear inside expected function bodies."""
    expected_placements = answer_key.get("expected_placements", {})
    if not expected_placements:
        return 1.0

    total = 0
    hits = 0

    # Build function boundary patterns
    def _find_function_body(content, func_name):
        """Find approximate function body text for func_name."""
        patterns = [
            # async function funcName or function funcName
            rf'(?:async\s+)?function\s+{re.escape(func_name)}\s*\(',
            # const funcName = (async) (...) =>
            rf'(?:const|let|var)\s+{re.escape(func_name)}\s*=\s*(?:async\s*)?\(',
            # const funcName = async (
            rf'(?:const|let|var)\s+{re.escape(func_name)}\s*=\s*async\s*\(',
            # class method: funcName(
            rf'^\s+(?:async\s+)?{re.escape(func_name)}\s*\(',
            # def funcName (Python)
            rf'def\s+{re.escape(func_name)}\s*\(',
        ]

        for pattern in patterns:
            match = re.search(pattern, content, re.MULTILINE)
            if match:
                start = match.start()
                # Find the next function definition after this one
                # Look for any of the function-start patterns
                next_func_patterns = [
                    r'(?:export\s+)?(?:async\s+)?function\s+\w+\s*\(',
                    r'(?:export\s+)?(?:const|let|var)\s+\w+\s*=\s*(?:async\s*)?\(',
                    r'def\s+\w+\s*\(',
                ]
                body_start = start + len(match.group())
                next_start = len(content)
                for np in next_func_patterns:
                    for m in re.finditer(np, content[body_start + 1:], re.MULTILINE):
                        candidate = body_start + 1 + m.start()
                        if candidate > body_start and candidate < next_start:
                            next_start = candidate
                            break

                return content[start:next_start]
        return None

    # Build camelCase variants of SDK call names
    def _variants(call_name):
        """Return both snake_case and camelCase variants of a call name."""
        variants = {call_name}
        # snake_case → camelCase: push_data → pushData
        parts = call_name.split(".")
        camel_parts = []
        for part in parts:
            words = part.split("_")
            camel_parts.append(words[0] + "".join(w.capitalize() for w in words[1:]))
        variants.add(".".join(camel_parts))
        return variants

    for sdk_call, func_names in expected_placements.items():
        call_variants = _variants(sdk_call)
        for func_name in func_names:
            total += 1
            found = False
            for _path, content in modified_files_content.items():
                # Direct check: SDK call inside the target function body
                body = _find_function_body(content, func_name)
                if body and any(v in body for v in call_variants):
                    found = True
                    break

                # Indirect check: target function calls a helper, and that helper
                # contains the SDK call. Look for any function call in the target
                # body, then check if that function contains the SDK call.
                if body:
                    # Find function calls in body (simple heuristic: word followed by ()
                    called_funcs = re.findall(r'(?:await\s+)?(\w+)\s*\(', body)
                    for called in called_funcs:
                        if called in (func_name, "if", "for", "while", "catch", "switch", "console", "throw", "return"):
                            continue
                        # Check if the called function contains the SDK call
                        for _p2, content2 in modified_files_content.items():
                            helper_body = _find_function_body(content2, called)
                            if helper_body and any(v in helper_body for v in call_variants):
                                found = True
                                break
                        if found:
                            break
                if found:
                    break
            if found:
                hits += 1

    return hits / total if total > 0 else 1.0


def _snake_to_camel(name):
    """Convert snake_case to camelCase: customer_key → customerKey."""
    parts = name.split("_")
    return parts[0] + "".join(w.capitalize() for w in parts[1:])


def check_required_params_present(modified_files_content, answer_key):
    """Check that required parameters appear near SDK calls."""
    required_params = answer_key.get("required_parameters", {})
    if not required_params:
        return 1.0

    all_content_lines = {}
    for path, content in modified_files_content.items():
        all_content_lines[path] = content.split("\n")

    call_scores = []
    for call_name, params in required_params.items():
        # Search for both snake_case and camelCase variants of the call
        call_variants = [call_name, _snake_to_camel(call_name)]
        # Also handle dotted names: customers.push_data → customers.pushData
        if "." in call_name:
            parts = call_name.split(".")
            call_variants.append(parts[0] + "." + _snake_to_camel(parts[1]))

        call_found = False
        param_hits = 0
        for path, lines in all_content_lines.items():
            for i, line in enumerate(lines):
                if any(v in line for v in call_variants):
                    call_found = True
                    # Look within 20 lines for each param (both snake and camel)
                    window = "\n".join(lines[max(0, i - 5):i + 21])
                    for param in params:
                        if param in window or _snake_to_camel(param) in window:
                            param_hits += 1
                    break
            if call_found:
                break

        if call_found and params:
            call_scores.append(param_hits / len(params))
        elif not call_found:
            call_scores.append(0.0)

    return sum(call_scores) / len(call_scores) if call_scores else 1.0


def check_all_handlers_modified(modified_files_content, answer_key):
    """Check that all lifecycle phases have at least one SDK call in the modified files."""
    expected_calls = answer_key.get("expected_calls", {})
    if not expected_calls:
        return 1.0

    all_content = "\n".join(modified_files_content.values())

    phases_covered = 0
    total_phases = len(expected_calls)

    for phase, calls in expected_calls.items():
        for call in calls:
            # Check both snake_case and camelCase variants
            if call in all_content or _snake_to_camel(call) in all_content:
                phases_covered += 1
                break
            # Also check dotted camelCase: customers.push_data → customers.pushData
            if "." in call:
                parts = call.split(".")
                camel_dotted = parts[0] + "." + _snake_to_camel(parts[1])
                if camel_dotted in all_content:
                    phases_covered += 1
                    break

    return phases_covered / total_phases if total_phases > 0 else 1.0


def check_webhook_route_added(modified_files_content):
    """Check for webhook route with Seam event types."""
    seam_events = [
        "access_code.set_on_device",
        "access_method.issued",
        "device.disconnected",
        "access_code.failed_to_set_on_device",
    ]

    all_content = "\n".join(modified_files_content.values())

    # Check for route with seam (case-insensitive) — supports Express, Flask, Rails patterns
    has_seam_route = bool(re.search(
        r'(?:'
        r'(?:router|app)\s*\.\s*(?:post|get|put|use)\s*\(\s*["\'/].*seam'  # Express
        r'|@\w+\.route\s*\(\s*["\'/].*seam'  # Flask
        r'|post\s+["\'/].*seam'  # Rails
        r')',
        all_content, re.IGNORECASE))

    if not has_seam_route:
        return 0.0

    # Check for event type strings
    events_found = sum(1 for evt in seam_events if evt in all_content)

    if events_found > 0:
        return 1.0
    else:
        return 0.5


# ---------------------------------------------------------------------------
# Main scoring
# ---------------------------------------------------------------------------

CHECK_DISPATCH = {
    "api_path_match": lambda content, diff, ak, ec: check_api_path_match(content, ec),
    "files_modified_match": lambda content, diff, ak, ec: check_files_modified_match(
        diff["changed_files"], diff["new_files"], ak),
    "calls_in_expected_functions": lambda content, diff, ak, ec: check_calls_in_expected_functions(content, ak),
    "required_params_present": lambda content, diff, ak, ec: check_required_params_present(content, ak),
    "all_handlers_modified": lambda content, diff, ak, ec: check_all_handlers_modified(content, ak),
    "webhook_route_added": lambda content, diff, ak, ec: check_webhook_route_added(content),
}


def score(pristine_dir, modified_dir, fixture_dir):
    """Run all checks and return scored results."""
    answer_key, eval_config, rubric = load_config(fixture_dir)
    diff = compute_diff(pristine_dir, modified_dir)

    # Read all changed + new files
    all_files = diff["changed_files"] + diff["new_files"]
    modified_files_content = read_modified_files(modified_dir, all_files)

    results = {"total": 0.0, "categories": {}}

    for cat in rubric["categories"]:
        name = cat["name"]
        weight = cat["weight"]
        check_fn = CHECK_DISPATCH.get(cat["check"])

        if check_fn is None:
            raw = 0.0
        else:
            raw = check_fn(modified_files_content, diff, answer_key, eval_config)

        weighted = round(raw * weight, 2)
        results["categories"][name] = {"score": round(raw, 4), "weighted": weighted}
        results["total"] += weighted

    results["total"] = round(results["total"], 2)
    return results


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(description="Rubric checker for Seam integration evals")
    parser.add_argument("--pristine", required=True, help="Path to pristine (unmodified) fixture app")
    parser.add_argument("--modified", required=True, help="Path to modified fixture app")
    parser.add_argument("--fixture-dir", required=True, help="Path to fixture directory (contains answer_key.json)")
    args = parser.parse_args()

    results = score(args.pristine, args.modified, args.fixture_dir)
    print(json.dumps(results, indent=2))
    return results


if __name__ == "__main__":
    main()
