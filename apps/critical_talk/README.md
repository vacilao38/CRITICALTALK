# Critical Talk Linux

Cliente Flutter para a etapa 1 do Critical Talk, focado inicialmente em Linux desktop.

## Escopo atual

Esta versao implementa o layout base da sala:

- navegacao lateral;
- cabecalho de sala;
- painel de voz e participantes;
- area de cena;
- chat;
- compositor de mensagem;
- painel de trilha;
- painel de dados;
- resumo de perfil.

O chat ja permite enviar mensagens locais pelo campo principal ou pela tecla Enter. O Bot Teste responde automaticamente com `mensagem recebida`, permitindo validar uma conversa basica sem backend.

O chat agora tambem suporta:

- renderizacao de markdown no estilo Obsidian para enfase, listas, blocos e codigo;
- neutralizacao de links markdown e wikilinks, exibindo apenas o texto visivel;
- envio local de imagens por seletor de arquivo no Linux;
- preview da imagem dentro da conversa.

O painel de voz agora tambem suporta:

- leitura real de microfones e saidas pelo PulseAudio;
- troca de microfone padrao;
- troca de saida padrao;
- mute local no cliente;
- indicador visual de atividade de fala para o usuario local;
- bot de teste emitindo audio no sistema para validar a saida selecionada.

Chat em tempo real, captura/publicacao de voz e trilhas reais entram nas proximas fatias.

## Rodar em desenvolvimento

```bash
flutter run -d linux
```

## Validar

```bash
flutter analyze
flutter test
flutter build linux
```

## Build gerado

Depois de `flutter build linux`, o executavel fica em:

```text
build/linux/x64/release/bundle/critical_talk
```
