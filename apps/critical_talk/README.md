# Critical Talk Linux

Cliente Flutter para a etapa 1 do Critical Talk, focado inicialmente em Linux desktop.

## Escopo atual

Esta versao agora tambem possui uma base local de usuario com:

- autenticacao por `user_name` + senha forte;
- cadastro sem email;
- identificador fixo opaco mostrado na primeira criacao;
- perfil local editavel com avatar/GIF e banner/GIF;
- persistencia local criptografada.

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

O painel de dados agora ja funciona com:

- expressoes como `d20`, `1d20`, `2d6+3` e `4d6kh3`;
- atalhos rapidos para dados comuns;
- registro de historico de rolagens na propria sessao;
- envio do resultado para o chat local.

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
- retorno local da propria voz para testar captacao e clareza;
- bot de teste emitindo audio no sistema para validar a saida selecionada.

O painel de trilha agora funciona sem Spotify e sem chaves externas:

- cadastro de arquivos locais de audio;
- preview privado;
- tocar na sala;
- pausar;
- parar;
- loop simples.

Voz em tempo real entre participantes continua como a prioridade tecnica seguinte, mas a validacao completa ficou pendente de teste com um segundo usuario conectado.

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
