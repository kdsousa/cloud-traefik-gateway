# 🚀 Cloud-traefik-gateway

Solução moderna, segura e pronta para produção de Proxy Reverso e Ingress Controller utilizando **Traefik v3**, **Docker Compose** e gerenciamento automático de certificados SSL/TLS com **Let's Encrypt** via protocolo ACME.

---

## 📌 Descrição do Projeto

Este repositório fornece a infraestrutura base de borda (Edge Proxy) para servidores e máquinas virtuais. Ele centraliza o recebimento de tráfego de internet nas portas padrão (80 e 443), cuida da emanação e renovação automática de certificados de segurança SSL/TLS e roteia o tráfego de forma inteligente para seus microsserviços e aplicações rodando em containers Docker.

### Principais Recursos
* **Traefik v3**: Único ponto de entrada (*Single Entry Point*) para o servidor.
* **SSL/TLS Automático**: Emissão e renovação de certificados gratuitos do Let's Encrypt (`tlsChallenge`).
* **Basic Auth Integrado**: Proteção por senha criptografada para o painel de controle (Dashboard).
* **Rede Docker Compartilhada**: Permite que novas aplicações conectem-se ao proxy de forma desacoplada.
* **Automação via Makefile**: Comandos simplificados para *setup*, *deploy*, leitura de *logs* e diagnóstico de *status*.

---

## 🏗️ Arquitetura e Fluxo de Requisição

```
[ Usuário / Navegador ]
          │
          ▼ (HTTPS / Porta 443)
   [ Cloudflare / DNS ]
          │
          ▼ (Redirecionamento para o IP da VM)
┌─────────────────────────────────────────────────────────────┐
│ Servidor Cloud (VM)                                         │
│                                                             │
│   ┌─────────────────────────────────────────────────────┐   │
│   │ Container Traefik (Rede: traefik)                   │   │
│   │                                                     │   │
│   │ - Emite/Valida SSL via Let's Encrypt                │   │
│   │ - Autentica o Dashboard via Basic Auth              │   │
│   └──────────┬──────────────────────────────┬───────────┘   │
│              │                              │               │
│              ▼                              ▼               │
│   ┌────────────────────┐         ┌────────────────────┐     │
│   │ App 1 (Web / API)  │         │ App 2 (Dashboard)  │     │
│   └────────────────────┘         └────────────────────┘     │
└─────────────────────────────────────────────────────────────┘
```

---

## 🛠️ Pré-requisitos

Antes de iniciar, certifique-se de cumprir os seguintes requisitos no seu ambiente:

1. **Domínio e DNS**:
   * Um registro tipo `A` apontando o seu domínio/subdomínio para o IP público do servidor.
   * Na Cloudflare, mantenha o Status do Proxy em **Somente DNS** (nuvem cinza) para permitir a validação do desafio TLS do Let's Encrypt.
2. **Portas de Rede / Firewall**:
   * Portas `80/TCP` (HTTP) e `443/TCP` (HTTPS) liberadas para entrada (*Inbound Rules*) no painel do seu provedor de nuvem (AWS, GCP, Oracle, Hetzner, etc.) e no firewall do SO (`ufw`).
3. **Chave SSH**:
   * Acesso SSH configurado e funcional entre a sua máquina local e o servidor remoto.
4. **Ambiente do Servidor**:
   * `Docker` e o plugin `Docker Compose` instalados na VM.

---

## 📁 Estrutura de Arquivos

```
.
├── docker-compose.yml       # Definição principal do container Traefik e Entrypoints
├── traefik_dynamic.yml      # Configurações dinâmicas (Middlewares e Basic Auth)
├── Makefile                 # Script de automação para deploy e manutenção
├── .env.example             # Modelo de variáveis de ambiente do servidor
├── .gitignore               # Arquivos ignorados pelo controle de versão
└── README.md                # Documentação do repositório
```

---

## ⚙️ Como Configurar

### 1. Configurar as Variáveis de Ambiente

Crie o seu arquivo `.env`.

```bash
touch .env
```

Edite o arquivo `.env` com as informações do seu servidor remoto:

```env
SERVER=ubuntu@seu-ip-ou-dominio
KEY=~/.ssh/sua_chave_privada.pem
REMOTE_PATH=~/traefik-proxy
```

---

### 2. Gerar a Hash de Senha para o Dashboard (Basic Auth)

Para proteger o Dashboard do Traefik, gere uma senha criptografada em **Bcrypt** utilizando um container temporário do Apache:

```bash
docker run --rm httpd:alpine htpasswd -nbB admin SUA_SENHA_AQUI
```

> **Exemplo de saída:** `admin:$2y$05$mXhL...`

Copie o resultado gerado e cole no arquivo `traefik_dynamic.yml`, dentro da seção `dashboard-auth`:

```yaml
http:
  middlewares:
    dashboard-auth:
      basicAuth:
        users:
          - 'admin:$2y$05$mXhL...ColeSuaHashAqui'
```

---

## 🚀 Comandos do Makefile

O projeto conta com um `Makefile` automatizado para simplificar o gerenciamento local e remoto.

| Comando | Descrição |
| :--- | :--- |
| `make help` | Exibe a lista interativa com todos os comandos disponíveis e suas descrições. |
| `make setup` | Sincroniza os arquivos, cria o `acme.json` com permissões `600`, cria a rede externa `traefik` e inicia o container no servidor. |
| `make deploy` | Sincroniza as alterações locais com o servidor e reinicia o serviço do Traefik. |
| `make logs` | Exibe os logs do Traefik em tempo real (`tail -f`) diretamente no seu terminal local. |
| `make status` | Mostra o estado de execução dos containers e da rede Docker no servidor remoto. |

---

## 🌐 Como Conectar Novos Containers de Outras Aplicações

Para expor uma nova aplicação (API, Website, Bot) através deste Proxy Ingress sem precisar alterar este repositório, siga o padrão abaixo no `docker-compose.yml` da sua aplicação:

```yaml
services:
  minha-app:
    image: nginx:alpine
    restart: always
    networks:
      - traefik
    labels:
      - "traefik.enable=true"
      # Regra de roteamento pelo domínio desejado
      - "traefik.http.routers.minha-app.rule=Host(`app.seu-dominio.com.br`)"
      - "traefik.http.routers.minha-app.entrypoints=websecure"
      - "traefik.http.routers.minha-app.tls.certresolver=myresolver"
      # Porta interna em que o seu container escuta
      - "traefik.http.services.minha-app.loadbalancer.server.port=80"

# Conecta à rede global externa gerenciada pelo Traefik
networks:
  traefik:
    external: true
```

---