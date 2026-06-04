# Direcao Tecnica

## Arquitetura sugerida

### Cliente

Recomendacao inicial: um unico cliente multiplataforma para Android e Linux.

Opcoes:

- Flutter: bom para Android e desktop Linux, interface consistente e desempenho aceitavel.
- React Native + Electron/Tauri: viavel, mas tende a exigir mais cola entre mobile e desktop.
- Kotlin Multiplatform: forte para Android, mas Linux desktop pode aumentar complexidade.

Direcao recomendada: Flutter, salvo se houver uma preferencia forte por outra stack.

### Backend

Responsabilidades:

- autenticacao simples;
- salas privadas;
- chat em tempo real;
- estado de usuarios na sala;
- rolagens;
- perfis;
- metadados de trilhas;
- regras cadastradas;
- sincronizacao de controles de musica;
- integracao com servico de voz.

Opcoes:

- Node.js com NestJS/Fastify e WebSocket.
- Elixir Phoenix, excelente para tempo real.
- Go, bom para servidor leve, mas com mais trabalho manual.

Direcao recomendada: Node.js/Fastify ou Phoenix. Para equipe pequena e iteracao rapida, Node.js costuma ser mais simples de contratar/manter; Phoenix e muito forte se o foco for tempo real robusto.

### Voz

Como o projeto nao quer P2P direto, a direcao mais segura e usar WebRTC com SFU.

Opcoes:

- LiveKit self-hosted.
- mediasoup.
- Janus.

Direcao recomendada para MVP: LiveKit self-hosted ou managed, porque reduz o volume de infraestrutura de voz que o projeto precisa manter.

## Dados e persistencia

### Banco principal

PostgreSQL para:

- usuarios;
- salas;
- perfis/personagens;
- mensagens;
- regras;
- playlists;
- configuracoes;
- historico de rolagens.

### Arquivos

Object storage compativel com S3 para:

- imagens do chat;
- avatares;
- banners;
- GIFs enviados;
- PDFs futuros;
- fundos/cenas.

Para desenvolvimento local, usar armazenamento em disco ou MinIO.

## Tempo real

Eventos por WebSocket:

- entrada/saida de sala;
- mensagens;
- status de voz;
- rolagens;
- alteracoes de perfil;
- controle de trilha;
- iniciativa;
- regras chamadas;
- alteracoes de cena.

## Trilhas sonoras

Spotify deve ser tratado como integracao com risco tecnico e de produto:

- preview URLs podem estar indisponiveis ou depreciadas dependendo do endpoint, mercado e politica atual da API;
- playback completo via Spotify normalmente depende de SDK, conta Premium e restricoes de plataforma;
- o app talvez precise suportar fontes alternativas ou arquivos proprios no futuro.

Direcao da etapa 1:

- separar o modulo de trilhas em uma camada de provedores;
- implementar uma interface generica de player;
- permitir Spotify como provedor quando viavel;
- deixar fallback planejado para arquivos locais, links externos ou biblioteca propria.

## Markdown

Usar parser real de Markdown com lista de recursos permitidos.

Na etapa 1:

- permitir enfase, negrito, italico, listas, codigo inline e blocos;
- bloquear links;
- sanitizar HTML;
- limitar tamanho antes de salvar e renderizar.

## Rolagem de dados

Comecar com uma gramatica simples:

- `d20`;
- `1d20`;
- `2d6+3`;
- `4d6kh3`;
- modificadores positivos e negativos.

Evoluir depois para vantagem/desvantagem, rolagem escondida e macros.

## Riscos principais

- Qualidade de audio no Android sem modo de chamada.
- Latencia e custo de servidor de voz.
- Integracao Spotify limitada por regras da plataforma.
- GIFs e imagens pesados em celulares de entrada.
- Escopo de RPG crescer rapido demais antes do nucleo ficar estavel.

## Decisoes abertas

- O app tera login permanente ou entrada por convite/nome temporario?
- As salas serao criadas por um mestre fixo?
- Mensagens devem ser criptografadas ponta a ponta ou apenas protegidas no transporte?
- O historico de chat sera permanente ou apagado apos a sessao?
- O projeto aceitara trilhas enviadas pelo mestre como arquivo proprio?
