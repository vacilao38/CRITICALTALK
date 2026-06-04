# MVP da Etapa 1

## Objetivo

Construir uma primeira versao jogavel, com o menor conjunto de recursos que prove que o Critical Talk funciona como sala online de RPG para amigos.

## Fluxo principal

1. Usuario abre o app.
2. Usuario escolhe nick, avatar e banner.
3. Usuario cria ou entra em uma sala.
4. Usuario seleciona microfone e saida de audio.
5. Usuario conversa por voz com o grupo.
6. Usuario envia mensagens e imagens.
7. Mestre toca, pausa, para e coloca trilha em loop.
8. Jogadores rolam dados no chat ou em painel dedicado.

## Telas iniciais

### Entrada

- Campo de nick.
- Escolha de avatar.
- Escolha de banner.
- Botao para criar sala.
- Campo para codigo/convite de sala.

### Sala

- Lista de participantes.
- Indicador de fala.
- Controles de microfone.
- Seletor de entrada e saida de audio.
- Chat.
- Painel de dados.
- Painel de trilha.
- Acesso rapido ao perfil.

### Perfil

- Nick.
- Avatar.
- Banner.
- Crop de imagem.
- Preview de GIF.

### Trilha

- Lista simples de faixas cadastradas.
- Preview privado.
- Play.
- Pause.
- Stop.
- Loop ligado/desligado.

## Modelo inicial de dados

### Usuario

- id
- nick
- avatar_url
- banner_url
- criado_em

### Sala

- id
- codigo_convite
- nome
- criada_por
- criada_em

### Mensagem

- id
- sala_id
- usuario_id
- tipo: texto ou imagem
- conteudo
- arquivo_url
- criada_em

### Rolagem

- id
- sala_id
- usuario_id
- expressao
- resultado
- detalhes
- criada_em

### Trilha

- id
- sala_id
- titulo
- provedor
- uri
- metadata
- criada_em

## Validacoes

- Mensagem de texto nao pode passar de 2000 caracteres.
- Links em Markdown devem ser bloqueados ou renderizados como texto comum.
- Imagens devem ter limite de tamanho.
- GIF de perfil deve ter limite de tamanho e dimensao.
- Sala deve ter limite configuravel de participantes.

## Testes de aceite

- Dois usuarios entram na mesma sala e conversam por voz.
- Usuario altera entrada e saida de audio.
- Mensagem Markdown aparece formatada.
- Link em Markdown nao vira link clicavel.
- Imagem enviada aparece no chat.
- Mensagem com mais de 2000 caracteres e recusada.
- Dado `1d20+5` retorna resultado e detalhes.
- Mestre toca preview sem tocar para todos.
- Mestre usa play, pause, stop e loop.
- Avatar e banner aparecem depois de salvar perfil.
