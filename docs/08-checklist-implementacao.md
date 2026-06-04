# Checklist de Implementacao

Legenda:

- `[x]` concluido
- `[~]` em andamento
- `[ ]` nao iniciado
- `[!]` depende de decisao tecnica ou pesquisa

## Fundacao

- `[x]` Documentacao inicial do produto
- `[x]` Roadmap por etapas
- `[x]` Ambiente Flutter Linux criado
- `[x]` Layout base da sala
- `[~]` Checklist central do projeto
- `[x]` Definir stack final do backend
- `[x]` Definir SFU/servico de voz
- `[x]` Definir estrategia de autenticacao e salas

## Etapa 1

### Base

- `[x]` Layout principal da sala
- `[ ]` Tela de entrada em sala
- `[ ]` Entrada por codigo/convite
- `[ ]` Persistencia local de configuracoes

### Comunicacao

- `[ ]` Voz basica em tempo real
- `[x]` Escolha de microfone no Linux
- `[x]` Escolha de saida de audio no Linux
- `[~]` Indicador real de quem esta falando
- `[ ]` Conexao com servidor/SFU
- `[ ]` Chat em tempo real com backend
- `[x]` Markdown com estilo Obsidian
- `[x]` Links markdown bloqueados/sanitizados
- `[x]` Envio local de imagens
- `[ ]` Upload remoto de imagens
- `[x]` Limite de 2000 caracteres

### Trilhas sonoras

- `[ ]` Cadastro de trilhas
- `[ ]` Preview de trilha
- `[ ]` Play
- `[ ]` Pause
- `[ ]` Stop
- `[ ]` Loop simples

### RPG

- `[ ]` Rolagem de dados funcional
- `[ ]` Historico de rolagens

### Personalizacao

- `[ ]` Troca de nick funcional
- `[ ]` Foto de perfil funcional
- `[ ]` Banner funcional
- `[ ]` Crop de imagem
- `[ ]` Suporte a GIF no perfil

## Etapa 2

### Comunicacao

- `[ ]` Supressao de ruido
- `[ ]` GIPHY
- `[ ]` Limite de 4000 caracteres

### Trilhas sonoras

- `[ ]` Playlists
- `[ ]` Categorias
- `[ ]` Ordem aleatoria
- `[ ]` Loop de sequencia

### RPG

- `[ ]` Iniciativa
- `[ ]` Edicao da ordem
- `[ ]` Multiplos turnos por personagem/NPC
- `[ ]` Banco de regras
- `[ ]` Botao/comando de regras

### Personalizacao

- `[ ]` Multiplos perfis por usuario

## Etapa 3

### Comunicacao

- `[ ]` Visualizacao de PDF no chat
- `[ ]` Abertura em pagina especifica

### Trilhas sonoras

- `[ ]` Dupla trilha
- `[ ]` Controle individual de trilhas simultaneas
- `[ ]` Loop de trecho
- `[ ]` Sequencia avancada de musica

### RPG

- `[ ]` Vida visivel
- `[ ]` CA visivel
- `[ ]` Condicoes visiveis
- `[ ]` NPCs do mestre
- `[ ]` Troca de personagem ativa
- `[ ]` Importacao de ficha Markdown
- `[ ]` Extracao de status da ficha
- `[ ]` Biblioteca de fundos/cenas
- `[ ]` Fundo/cena da sala

### Personalizacao

- `[ ]` Fonte customizada para nome
- `[ ]` Cor customizada para nome

## Checklist especifico de voz

### Ambiente Linux

- `[x]` `pulseaudio` presente
- `[x]` `alsa-utils` presente
- `[x]` `pactl` presente
- `[x]` `arecord` presente
- `[x]` `libasound2-dev` instalado
- `[x]` `libpulse-dev` instalado
- `[x]` `portaudio19-dev` instalado
- `[x]` `libwebrtc-audio-processing-dev` instalado

### App Linux

- `[x]` Listar microfones reais
- `[x]` Listar saidas reais
- `[x]` Selecionar microfone ativo
- `[x]` Selecionar saida ativa
- `[x]` Bot local de teste emitindo audio no sistema
- `[x]` Indicador visual de fala local
- `[ ]` Medidor de entrada
- `[ ]` Captura de audio local
- `[ ]` Publicacao de audio no SFU
- `[ ]` Recepcao de audio remoto
- `[x]` Controle de mute/unmute
- `[ ]` Controle de volume por participante

### Infraestrutura

- `[x]` Escolher entre LiveKit, mediasoup ou Janus
- `[ ]` Subir instancia local de teste
- `[ ]` Gerar tokens de acesso
- `[ ]` Entrar/sair de sala com voz
- `[ ]` Teste com 2 clientes Linux
- `[ ]` Teste com Linux + Android
