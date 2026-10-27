# ==============================================================================
# CONFIGURAÇÕES DE AMBIENTE
# ==============================================================================
# Carrega as variáveis do arquivo .env se ele existir localmente
-include .env

# Variáveis com valores padrão (podem ser sobrescritas no .env ou via terminal)
SERVER      ?= usuario@ip_ou_dominio_do_servidor
KEY         ?= ~/.ssh/sua_chave.pem
REMOTE_PATH ?= ~/traefik-proxy

# Nome do projeto extraído automaticamente da pasta atual
PROJECT_NAME := $(shell basename $(shell pwd))

.PHONY: help rsync setup deploy logs status

# ==============================================================================
# COMANDOS PRINCIPAIS
# ==============================================================================

## help: Exibe esta lista de comandos e descrições
help:
	@echo "Uso: make [comando]"
	@echo ""
	@echo "Comandos disponíveis:"
	@sed -n 's/^##//p' $(MAKEFILE_LIST) | column -t -s ':'

## rsync: Sincroniza os arquivos locais com o servidor remoto (exceto sensíveis/temporários)
rsync:
	@echo "--> Sincronizando arquivos com o servidor remoto..."
	rsync -azv \
		--exclude '.git*' \
		--exclude '.env' \
		--exclude 'acme.json' \
		-e "ssh -i $(KEY)" . $(SERVER):$(REMOTE_PATH)

## setup: Configuração inicial no servidor (cria acme.json, permissões e rede do Docker)
setup: rsync
	@echo "--> Executando setup inicial no servidor..."
	ssh -i $(KEY) $(SERVER) "\
		mkdir -p $(REMOTE_PATH) && \
		cd $(REMOTE_PATH) && \
		touch acme.json && \
		chmod 600 acme.json && \
		docker network create traefik || true && \
		docker compose up -d"

## deploy: Atualiza os arquivos no servidor e reinicia o container
deploy: rsync
	@echo "--> Atualizando aplicação no servidor..."
	ssh -i $(KEY) $(SERVER) "\
		cd $(REMOTE_PATH) && \
		docker compose down && \
		docker compose up -d"

## logs: Exibe os logs em tempo real do Traefik no servidor
logs:
	ssh -i $(KEY) $(SERVER) "docker logs traefik -f --tail 100"

## status: Mostra o estado dos containers e redes no servidor
status:
	ssh -i $(KEY) $(SERVER) "cd $(REMOTE_PATH) && docker compose ps"