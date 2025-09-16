VENV=.venv
PYTHON=$(VENV)/bin/python
PIP=$(VENV)/bin/pip

.PHONY: venv deps web notion both

venv:
@test -d $(VENV) || python3 -m venv $(VENV)

deps: venv
@. $(VENV)/bin/activate; pip install -U pip wheel
@. $(VENV)/bin/activate; pip install -r requirements.txt || true

web: deps
@APP_FILE=$(APP_FILE) ./run.sh web

notion: deps
@NOTION_ENTRY=$(NOTION_ENTRY) NOTION_TOKEN=$(NOTION_TOKEN) NOTION_PAGE_ID=$(NOTION_PAGE_ID) ./run.sh notion

both: deps
@APP_FILE=$(APP_FILE) NOTION_ENTRY=$(NOTION_ENTRY) NOTION_TOKEN=$(NOTION_TOKEN) NOTION_PAGE_ID=$(NOTION_PAGE_ID) ./run.sh both
