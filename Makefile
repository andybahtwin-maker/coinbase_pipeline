.PHONY: demo report fmt lint clean

demo:
./scripts/run_demo_showcase.sh

report:
bash _ops_size_report.sh || true
@echo "Open report_repo_health.md"

fmt:
python3 -m pip install -q --upgrade pip black ruff
ruff check . --fix || true
black . || true

lint:
python3 -m pip install -q --upgrade pip ruff
ruff check .

clean:
rm -rf __pycache__ */__pycache__ .pytest_cache .mypy_cache .ruff_cache
