# Critical Talk

Critical Talk e um aplicativo para pequenos grupos de RPG jogarem online com voz, chat, imagens, trilhas sonoras, rolagem de dados e personalizacao de perfis.

O foco do projeto e ser leve, privado e confortavel em dispositivos simples, funcionando em Android e Linux Mint 20 ou superior.

## Documentacao

- [Visao geral](docs/00-visao-geral.md)
- [Requisitos do produto](docs/01-requisitos.md)
- [Roadmap por etapas](docs/02-roadmap.md)
- [Direcao tecnica](docs/03-direcao-tecnica.md)
- [MVP da etapa 1](docs/04-mvp-etapa-1.md)
- [Backlog inicial](docs/05-backlog.md)
- [Ambiente de desenvolvimento](docs/06-ambiente-desenvolvimento.md)
- [Audio no Linux](docs/07-audio-linux.md)
- [Checklist de implementacao](docs/08-checklist-implementacao.md)
- [Usuarios e seguranca](docs/09-usuarios-seguranca.md)

## Prioridade atual

A primeira entrega deve provar o nucleo do produto:

- sala privada para um grupo pequeno;
- comunicacao por voz sem supressao de ruido;
- chat com markdown, imagens e limite de 2000 caracteres;
- selecao de entrada e saida de audio;
- controle basico de trilha sonora;
- rolagem de dados;
- perfil com nick, foto/GIF e banner.

## Projeto Linux

O cliente inicial da etapa 1 fica em [apps/critical_talk](apps/critical_talk).

Para rodar:

```bash
cd apps/critical_talk
flutter run -d linux
```

## Decisoes que precisam ser validadas cedo

- Qual tecnologia sera usada no cliente Android/Linux.
- Qual servidor de voz sera usado para evitar P2P.
- Como tratar trilhas do Spotify, ja que preview e playback possuem limitacoes de API/SDK.
- Se o app sera usado somente por convite/manual ou com contas permanentes.
