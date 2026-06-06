# Audio no Linux

Este documento concentra o que o projeto precisa no Linux para iniciar a etapa de voz com menos atrito.

## O que ja existe neste ambiente

Ja estao presentes:

- ALSA runtime e utilitarios;
- PulseAudio runtime e utilitarios;
- GStreamer;
- `pactl`;
- `arecord`;
- `libwebrtc-audio-processing1`.

## O que ainda faltava para desenvolvimento

Nao estavam instalados quando o ambiente foi auditado:

- `libasound2-dev`;
- `libpulse-dev`;
- `libgstreamer1.0-dev`;
- `libgstreamer-plugins-base1.0-dev`;
- `portaudio19-dev`;
- `libwebrtc-audio-processing-dev`.

## O que instalar primeiro

### Obrigatorio para iniciar a voz no Linux

- `libasound2-dev`;
- `libpulse-dev`.

### Recomendado para laboratorio e futuras iteracoes

- `libgstreamer1.0-dev`;
- `libgstreamer-plugins-base1.0-dev`;
- `portaudio19-dev`;
- `libwebrtc-audio-processing-dev`.

## Observacao importante para trilha sonora local

O plugin Linux usado na etapa 1 de trilha sonora local depende de:

- `gstreamer-1.0`;
- `gstreamer-app-1.0`;
- `gstreamer-audio-1.0`.

Na pratica, isso significa instalar os headers:

- `libgstreamer1.0-dev`;
- `libgstreamer-plugins-base1.0-dev`.

Sem esses pacotes, o `flutter build linux` falha durante o CMake do `audioplayers_linux`.

## Ferramentas de verificacao uteis

- `arecord -l`: listar dispositivos de captura.
- `pactl list short sources`: listar microfones vistos pelo PulseAudio.
- `pactl list short sinks`: listar saidas de audio.

## Direcao tecnica recomendada

- Cliente Linux/Android em Flutter.
- Voz em tempo real via WebRTC.
- SFU externo em vez de P2P direto.
- Servico escolhido: LiveKit.
- Estrategia inicial: self-hosted para desenvolvimento e testes fechados.
- Opcao managed caso precise terceirizar operacao: LiveKit Cloud.

## Estado atual do projeto

Ja conseguimos validar localmente no cliente Linux:

- escolha de microfone e saida;
- mute local;
- indicador visual de fala local;
- retorno local da propria voz;
- audio de teste por bot local.

O proximo passo prioritario continua sendo a voz em tempo real entre participantes, mas essa etapa ficou temporariamente bloqueada ate haver um segundo usuario disponivel para teste real de chamada.

## Alternativas pagas avaliadas

- Daily: boa opcao managed, com modelo simples de cobranca por participante/minuto.
- Agora: madura, mas pouco atraente aqui por causa do custo minimo mensal.

## Observacao sobre PipeWire

Este Linux Mint 20 esta orientado a PulseAudio. PipeWire pode entrar depois, mas nao e prerequisito para comecar a etapa 1 de voz aqui.
