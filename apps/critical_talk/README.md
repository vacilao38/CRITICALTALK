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

Os dados exibidos ainda sao mockados. Voz, chat em tempo real, trilhas reais, envio de imagem e rolagem funcional entram nas proximas fatias.

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
