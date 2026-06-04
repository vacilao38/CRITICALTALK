# Requisitos do Produto

## Comunicacao por voz

### Essencial

- Voz em tempo real.
- Arquitetura sem P2P direto entre usuarios.
- Servidor ou servico intermediario para rotear audio.
- Selecao de microfone no Android e Linux.
- Selecao de saida de audio quando suportado pela plataforma.
- Qualidade aceitavel sem acionar comportamento de chamada telefonica no Android.

### Evolucao

- Supressao de ruido leve.
- Controle individual de volume por usuario.
- Indicador visual de quem esta falando.

## Chat

### Essencial

- Mensagens de texto em tempo real.
- Markdown compativel com uso comum no Obsidian, exceto links.
- Envio de imagens do dispositivo.
- Suporte inicial a mensagens de ate 2000 caracteres.

### Evolucao

- Mensagens de ate 4000 caracteres.
- Mensagens de ate 7000 caracteres.
- GIFs via GIPHY.
- Visualizacao de PDFs dentro do chat.
- Selecionar pagina especifica de um PDF.

## Trilhas sonoras

### Essencial

- Buscar ou cadastrar musicas/trilhas.
- Preview para quem vai tocar a musica.
- Play, pause, stop e loop.

### Evolucao

- Playlists.
- Categorias de musicas.
- Ordem aleatoria.
- Loop de sequencia.
- Dupla trilha: ambiente e musica principal simultaneas.
- Loop de trecho especifico.
- Sequencias avancadas com introducao, loop repetido e transicao.

## RPG

### Essencial

- Rolagem de dados.
- Comandos ou interface rapida para dados comuns.
- Resultado publico ou escondido, quando implementado.

### Evolucao

- Iniciativa editavel.
- Multiplas acoes/turnos para o mesmo personagem ou NPC.
- Banco de regras com nome, origem, conteudo e edicao.
- Vida, CA e condicoes sempre visiveis.
- NPCs adicionados pelo mestre.
- Troca de personagens.
- Importacao de ficha em Markdown.
- Imagem de fundo/cena com biblioteca.
- Mapa em grid no futuro.

## Personalizacao

### Essencial

- Troca de nick.
- Foto de perfil.
- Banner de perfil.
- Crop de imagem.
- Suporte a GIF como avatar.

### Evolucao

- Multiplos perfis/personagens por usuario.
- Fonte e cor customizadas para nome.

## Requisitos nao funcionais

- Baixo consumo de memoria e bateria.
- Tolerancia a conexoes instaveis.
- Baixa latencia para voz.
- Interface simples durante a sessao.
- Dados persistidos com backup possivel.
- Logs suficientes para diagnosticar falhas de conexao.
