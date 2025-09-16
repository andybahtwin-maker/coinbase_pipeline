.PHONY: run demo clean prune

run:
./run_simple.sh

demo:
APP_DEMO_FALLBACK=true ./run_simple.sh

clean:
rm -rf .cache __pycache__ .pytest_cache .streamlit/logs

prune:
scripts/repo_prune_safe.sh
