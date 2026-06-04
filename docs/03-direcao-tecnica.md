# Direcao Tecnica

## Arquitetura sugerida

### Cliente

Recomendacao inicial: um unico cliente multiplataforma para Android e Linux.

Opcoes:

- Flutter: bom para Android e desktop Linux, interface consistente e desempenho aceitavel.
- React Native + Electron/Tauri: viavel, mas tende a exigir mais cola entre mobile e desktop.
- Kotlin Multiplatform: forte para Android, mas Linux desktop pode aumentar complexidade.

Decisao fechada: Flutter.

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

Stack final do backend:

- Node.js 20;
- NestJS;
- adaptador Fastify;
- WebSocket para eventos do app;
- PostgreSQL como banco principal;
- Redis para presenca, cache e coordenacao leve;
- S3/MinIO para arquivos.

Justificativa:

- NestJS ajuda a organizar autenticacao, salas, emissao de tokens, WebSocket e integracoes sem deixar o projeto virar um bloco solto cedo demais.
- Fastify mantem bom desempenho e baixo overhead.
- Node.js conversa bem com SDKs e servicos do ecossistema realtime, inclusive LiveKit.
- PostgreSQL atende bem usuarios, salas, membros, mensagens, regras e trilhas.
- Redis simplifica presenca, rate limit, convites temporarios e estados curtos.

### Voz

Como o projeto nao quer P2P direto, a direcao mais segura e usar WebRTC com SFU.

Decisao fechada:

- protocolo de media: WebRTC;
- arquitetura: SFU;
- servico escolhido: LiveKit;
- estrategia de rollout: LiveKit self-hosted no desenvolvimento e homologacao, com opcao de migrar para LiveKit Cloud quando a operacao precisar de menos manutencao.

Justificativa:

- O projeto precisa voz em tempo real sem P2P direto.
- LiveKit ja entrega SFU, SDK Flutter e um caminho mais curto para publicar/receber audio do que montar mediasoup ou Janus do zero.
- Para um grupo pequeno, self-hosted tende a ser o caminho mais barato no inicio.
- Se a manutencao de infraestrutura passar a atrapalhar, LiveKit Cloud vira o plano B natural sem reescrever o cliente.

Alternativas pagas consideradas:

- Daily: boa opcao managed e simples de contratar, especialmente para audio/video sem operar SFU proprio.
- Agora: tecnicamente madura, mas menos atraente para este projeto por causa do modelo de custo minimo mensal.

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

### Autenticacao e salas

Decisao fechada:

- autenticacao propria do backend;
- contas persistentes por usuario;
- login por `user_name` e senha;
- tokens `access` e `refresh`;
- salas privadas com codigo de convite;
- membros precisam estar associados a sala para entrar;
- token de voz do LiveKit gerado pelo backend no momento de entrar na sala;
- papeis iniciais: `owner` e `member`.

Fluxo recomendado:

1. Usuario cria conta e faz login no backend.
2. Backend entrega `access token` curto e `refresh token` longo.
3. Usuario cria uma sala ou entra por convite.
4. Backend valida se o usuario pertence a sala.
5. Backend gera token curto do LiveKit para aquela sala e aquele usuario.
6. Cliente conecta no SFU usando esse token.

Justificativa:

- O projeto ja precisa de identidade persistente para perfis, historico, imagens, multiplos personagens e papeis futuros.
- Convite por sala mantem o produto privado e leve para grupo pequeno.
- Separar token do app de token do SFU evita expor permissao de voz fora do controle do backend.
- `user_name` e senha forte removem dependencia de email no onboarding inicial e combinam melhor com a proposta de grupos pequenos por convite.

### Modelo de usuario e seguranca

Direcao fechada:

- sem email no cadastro;
- `user_name` como identidade primaria de autenticacao;
- senha forte com minimo de 8 caracteres, maiuscula, minuscula, numero e caractere especial;
- ID fixo opaco gerado a partir de aleatoriedade forte com complemento de entropia organica do momento de criacao;
- senha armazenada apenas como derivacao Argon2id com `salt`;
- blob local de usuarios gravado de forma criptografada;
- chave inicial do ID exibida no primeiro cadastro para pareamento/manual match.

Fechando brechas importantes:

- a entropia organica humana nao pode ser a base unica do ID; ela entra apenas como insumo complementar.
- a fonte primaria do ID deve continuar sendo aleatoriedade criptograficamente forte.
- senha nao deve ser "criptografada para recuperar depois"; ela deve ser derivada por hash resistente.
- o ID pode ser mostrado ao usuario na criacao, mas precisa permanecer persistido localmente apenas dentro do armazenamento protegido do app.
- no cliente Linux atual, a protecao local cobre hash da senha e criptografia AES-GCM do armazenamento; no backend futuro, isso evolui para segredo de servidor e, idealmente, keyring/secret store do sistema operacional quando aplicavel.

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

## Decisoes em aberto

- Se o `owner` podera promover outro membro a administrador depois.
- Se o historico de chat sera permanente ou apagado por sala/sessao.
- Se trilhas proprias enviadas pelo mestre entram ja na etapa 1 ou depois.
- Se a migracao para LiveKit Cloud sera necessaria antes do Android entrar.
