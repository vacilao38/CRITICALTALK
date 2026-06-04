# Ambiente de Desenvolvimento

Este documento prepara a instalacao das dependencias de desenvolvimento do Critical Talk em Linux Mint 20.

## Stack preparada

- Flutter/Dart para cliente Android e Linux desktop.
- Ferramentas nativas para build Linux: clang, cmake, ninja, pkg-config e GTK.
- Bibliotecas de desenvolvimento de audio para Linux: ALSA, PulseAudio, WebRTC Audio Processing e PortAudio.
- Java 17 para toolchain Android.
- Node.js 20 e npm para backend, scripts e ferramentas auxiliares.
- Docker e docker-compose para infraestrutura local.
- PostgreSQL client para acessar banco local ou containerizado.
- Git, curl, unzip, xz-utils e zip.

## Script de instalacao

O script fica em:

```bash
scripts/install-dev-deps-mint20.sh
```

Ele deve ser executado com permissao administrativa:

```bash
sudo bash scripts/install-dev-deps-mint20.sh
```

## Verificacao depois da instalacao

```bash
flutter doctor
node --version
npm --version
docker --version
psql --version
```

## Observacoes

- A senha sudo nao deve ser salva em arquivos do projeto.
- O Flutter instalado por Snap pode exigir ajustes extras apontados pelo `flutter doctor`.
- Se Docker for instalado pela primeira vez, talvez seja necessario adicionar o usuario ao grupo `docker` e reiniciar a sessao.
- Android Studio ou Android SDK ainda podem ser necessarios para builds Android completos.
- Como ainda nao existe codigo do app, ainda nao ha dependencias de projeto como `flutter pub get` ou `npm install`.
- Para a etapa de voz no Linux, os headers `libasound2-dev` e `libpulse-dev` sao especialmente importantes.

## Proximo passo apos instalar

Depois que o ambiente estiver pronto, o proximo passo recomendado e criar o esqueleto do monorepo:

```text
apps/
  mobile_desktop/
services/
  api/
infra/
  docker-compose.yml
docs/
scripts/
```
