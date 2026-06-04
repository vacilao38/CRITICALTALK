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
- `portaudio19-dev`;
- `libwebrtc-audio-processing-dev`.

## O que instalar primeiro

### Obrigatorio para iniciar a voz no Linux

- `libasound2-dev`;
- `libpulse-dev`.

### Recomendado para laboratorio e futuras iteracoes

- `portaudio19-dev`;
- `libwebrtc-audio-processing-dev`.

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

## Alternativas pagas avaliadas

- Daily: boa opcao managed, com modelo simples de cobranca por participante/minuto.
- Agora: madura, mas pouco atraente aqui por causa do custo minimo mensal.

## Observacao sobre PipeWire

Este Linux Mint 20 esta orientado a PulseAudio. PipeWire pode entrar depois, mas nao e prerequisito para comecar a etapa 1 de voz aqui.
