# Copyright (c) 2025 Andrey Chuyan (oksigen077777@gmail.com)

# locals
export LANG = C.UTF-8
export LC_ALL = C.UTF-8

# env
SHELL        := /bin/bash
.DEFAULT_GOAL := help

# load .env
ifneq ("$(wildcard .env)","")
	include .env
	export
endif

# если есть test.env — подключаем
ifneq ("$(wildcard test.env)","")
  include test.env
  export
endif

help: ## Показать справку по командам
	@awk 'BEGIN {FS = ":.*?## "} \
		/^[a-zA-Z_-]+:.*?## / { \
			printf "\033[36m%-20s\033[0m %s\n", $$1, $$2 \
		}' $(MAKEFILE_LIST)

# --- переменные
IMAGE_NAME    	= locust-test
LOCUST_FILE   	= locustfile.py
REPORTS_DIR   	?= $(CURDIR)/reports
BASE_CSV_PREFIX	=	base

# # параметры base теста
# USERS         ?= 150	# максимальное число пользователей (виртуальных клиентов), участвующих в тесте.
# SPAWN_RATE    ?= 10		# скорость "рождения" пользователей в секунду.
# RUN_TIME      ?= 1m		# длительность теста
# CSV_PREFIX    ?= base

# # Пороги для проверки готовности
# MIN_RPS   ?= 50
# MAX_ERRS  ?= 1
# MAX_P50   ?= 500
# MAX_P90   ?= 900
# MAX_P95   ?= 1500
# MAX_MAX   ?= 2500


check-docker: ## Проверить, что Docker установлен
	@command -v docker > /dev/null 2>&1 || { \
		echo "Docker не найден. Установите Docker: https://docs.docker.com/get-docker/"; \
		exit 1; \
	}

build: check-docker ## Собрать Docker-образ locust-test
	docker build -t $(IMAGE_NAME) .

run-web: check-docker build ## Запустить Locust с Web-UI на 8089
	docker run --rm -it \
		-p 8089:8089 \
		-v $(CURDIR)/$(LOCUST_FILE):/app/$(LOCUST_FILE) \
		$(IMAGE_NAME) \
		--host $(HOST) \
		--web-host 0.0.0.0

clean: ## Удалить локальный Docker-образ
	@if docker image inspect $(IMAGE_NAME) > /dev/null 2>&1; then \
		docker rmi -f $(IMAGE_NAME) && echo "Образ $(IMAGE_NAME) удалён."; \
	else \
		echo "Образ $(IMAGE_NAME) не найден."; \
	fi


test: check-docker build ## Запустить тест, сохранить CSV в ./reports
	mkdir -p $(REPORTS_DIR)
	- docker run --rm \
		-v $(REPORTS_DIR):/app/reports \
		$(IMAGE_NAME) \
		-f $(LOCUST_FILE) \
		--host $(HOST) \
		--headless \
		--users $(BASE_USERS) \
		--spawn-rate $(BASE_SPAWN_RATE) \
		--run-time $(BASE_RUN_TIME) \
		--csv=reports/$(BASE_CSV_PREFIX)

# ---------------- готовность после теста ------------------
check: ## Проверить готовность приложения после make test
	@file="$(REPORTS_DIR)/$(BASE_CSV_PREFIX)_stats.csv"; \
	if [[ ! -f "$$file" ]]; then \
		echo "❌  Файл $$file не найден – сначала запустите test"; exit 1; \
	fi; \
	read -r rps errs p50 p90 p95 max < <( tail -n1 "$$file" | awk -F',' '{ print $$10, $$11, $$12, $$16, $$17, $$8 }' ); \
	echo "→ RPS=$$rps  Err/s=$$errs  p50=$$p50  p90=$$p90  p95=$$p95  max=$$max"; \
	awk -v r="$$rps" -v e="$$errs" -v p50="$$p50" -v p90="$$p90" -v p95="$$p95" -v mx="$$max" \
		-v MR="$(MIN_RPS)" -v ME="$(MAX_ERRS)" -v P50="$(MAX_P50)" -v P90="$(MAX_P90)" -v P95="$(MAX_P95)" -v MX="$(MAX_MAX)" \
    'BEGIN { exit !(r>=MR && e<=ME && p50<=P50 && p90<=P90 && p95<=P95 && mx<=MX) }'; \
	if [[ $$? -eq 0 ]]; then \
		echo "✔️  APPLICATION READY"; exit 0; \
	else \
		echo "❌  APPLICATION NOT READY";  \
	fi


# ---------------- сценарии -----------------
spectest-ramp-up:	## Ramp-up: плавно дойти до 200 юзеров за 2m
	@$(MAKE) test 
		BASE_USERS=$(RAMP_USERS) 
		BASE_SPAWN_RATE=$(RAMP_SPAWN_RATE) 
		BASE_RUN_TIME=$(RAMP_RUN_TIME) 
		BASE_CSV_PREFIX=$(RAMP_CSV_PREFIX)

spectest-stress:	## Stress: увеличиваем до отказа (1000 юзеров, +50/мин, 30m)
	@$(MAKE) test 
		BASE_USERS=$(STRESS_USERS) 
		BASE_SPAWN_RATE=$(STRESS_SPAWN_RATE) 
		BASE_RUN_TIME=$(STRESS_RUN_TIME) 
		BASE_CSV_PREFIX=$(STRESS_CSV_PREFIX)

spectest-soak:	## Soak: длительный тест (100 юзеров, 3h)
	@$(MAKE) test 
		BASE_USERS=$(SOAK_USERS) 
		BASE_SPAWN_RATE=$(SOAK_SPAWN_RATE) 
		BASE_RUN_TIME=$(SOAK_RUN_TIME) 
		BASE_CSV_PREFIX=$(SOAK_CSV_PREFIX)
