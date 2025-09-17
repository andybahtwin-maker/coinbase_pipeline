.PHONY: restart sync run demo

restart:
	./scripts/restart_clean.sh

run:
	streamlit run dashboard/simple_app.py --server.port=8501 --server.headless=false

demo:
	APP_DEMO_FALLBACK=true streamlit run dashboard/simple_app.py --server.port=8501 --server.headless=false

sync:
	./scripts/safe_sync_to_github.sh
