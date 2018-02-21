###
# Project commands
##

# Project variables
TARGET = lite
URL = http://localhost:8080

# Directories
BIN = bin
LOGS = logs
SCRIPTS = scripts
PIPELINES = pipelines
SUBMODULES = .submodules

COMPOSE_FILE = $(SUBMODULES)/concourse-docker/docker-compose.yml
KEYS = $(SUBMODULES)/concourse-docker/keys

# Executables
FLY = $(BIN)/fly

$(shell mkdir -p $(LOGS) $(BIN))

# Collects all pipelines under the pipeline directory
ALL_PIPELINES = $(foreach pipeline,$(wildcard $(PIPELINES)/*),$(shell echo $(pipeline) | sed 's/.*_//'))

# Environment variables
export PATH := ./$(BIN):./$(SCRIPTS):$(SUBMODULES)/bash-logger:$(PATH)
export LOGFILE := $(LOGS)/$(shell date '+%Y-%m-%d').log

# Get OS and Processor type
ifeq ($(OS),Windows_NT)
	OS = windows
	ifeq ($(PROCESSOR_ARCHITEW6432),AMD64)
		PROCESSOR = amd64
	else
		ifeq ($(PROCESSOR_ARCHITECTURE),AMD64)
			PROCESSOR = amd64
		endif
		ifeq ($(PROCESSOR_ARCHITECTURE),x86)
			PROCESSOR = i386
		endif
	endif
else
	UNAME_S = $(shell uname -s)
	ifeq ($(UNAME_S),Linux)
	OS = linux
		UNAME_P := $(shell uname -p)
		ifeq ($(UNAME_P),x86_64)
			PROCESSOR = amd64
		endif
		ifneq ($(filter %86,$(UNAME_P)),)
			PROCESSOR = i386
		endif
		ifneq ($(filter arm%,$(UNAME_P)),)
			PROCESSOR = arm
		endif
	endif
	ifeq ($(UNAME_S),Darwin)
	OS = darwin
		PROCESSOR = amd64
	endif
endif

# 
.PHONY: *

keys:
	$(SCRIPTS)/keygen.sh $(KEYS)
# keys

start: keys
	env CONCOURSE_NO_REALLY_I_DONT_WANT_ANY_AUTH=true docker-compose -f $(COMPOSE_FILE) up -d
# start

stop:
	docker-compose -f $(COMPOSE_FILE) stop
# stop

destroy: stop
	docker-compose -f $(COMPOSE_FILE) rm

	$(SCRIPTS)/keydegen.sh $(KEYS)
# destroy

fly:
ifeq (,$(wildcard $(FLY)))
	wget -O $(FLY) "$(URL)/api/v1/cli?arch=$(PROCESSOR)&platform=$(OS)"
endif
	@chmod +x $(FLY)
# fly

login: fly
	@$(FLY) -t $(TARGET) login -c $(URL)
# login

# Pipelines

list-pipelines:
	@for pipeline in $(ALL_PIPELINES); do echo $$pipeline; done
# list pipelines

pipelines: $(ALL_PIPELINES)

%: login
	@echo "Running pipeline: %"
	$(SCRIPTS)/run-pipeline.sh -t $(TARGET) -s $(PIPELINES) $(@)
# %

# Makefile
