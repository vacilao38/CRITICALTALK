# Usuarios e Seguranca

Este documento consolida o plano de implementacao para autenticacao, objeto usuario, perfil, identificacao e seguranca.

## Decisoes fechadas

- cadastro sem email;
- autenticacao por `user_name` + senha;
- senha forte com minimo de 8 caracteres, letras maiusculas e minusculas, numero e caractere especial;
- ID fixo opaco para cada usuario;
- foto/GIF de perfil;
- banner/GIF com crop visual por alinhamento vertical;
- campo `profileIds` reservado para multiplos perfis futuros;
- armazenamento local criptografado para a fase Linux atual.

## Fechando brechas do plano

### 1. ID e entropia

O pedido de "hash semi aleatorio + movimento humano organico" foi ajustado para um desenho mais seguro:

- a base do ID vem de aleatoriedade forte gerada pelo sistema;
- a cadencia humana da digitacao no cadastro entra apenas como entropia complementar;
- o resultado final e passado por hash antes de ser formatado.

Assim evitamos depender de uma fonte de entropia instavel, previsivel ou insuficiente.

### 2. Senha

Senha nao deve ser guardada de forma reversivel.

Implementacao escolhida:

- derivacao por Argon2id;
- `salt` aleatorio por usuario;
- comparacao em tempo constante na autenticacao.

### 3. Criptografia local

Como o app ainda nao depende de backend, os dados de usuario precisam ficar protegidos localmente.

Implementacao escolhida:

- blob JSON do cadastro gravado em AES-GCM;
- chave de instalacao gerada localmente e reutilizada para abrir o blob;
- ID, perfil e hash/salt de senha ficam apenas dentro desse blob.

Observacao honesta: isso protege bem melhor do que texto puro, mas ainda nao substitui segredo de servidor ou keyring nativo do sistema. E a base correta para a etapa atual.

## Objeto usuario

Campos atuais:

- `userId`
- `userName`
- `createdAt`
- `profile.avatar`
- `profile.banner`
- `profile.bannerAlignmentY`
- `profile.profileIds`

## Fluxo implementado no cliente Linux

1. Usuario escolhe `user_name` e senha.
2. O app valida regras de nome e senha.
3. O app coleta pequenas variacoes temporais de digitacao como entropia complementar.
4. O `userId` fixo e gerado.
5. A senha vira hash Argon2id com `salt`.
6. O usuario e persistido em armazenamento criptografado.
7. A chave inicial do ID e exibida uma vez apos o cadastro.
8. O usuario entra na sessao autenticada.

## Perfil implementado

Ja existe no cliente Linux:

- tela de autenticacao com cadastro e login;
- perfil local editavel;
- troca de nome de usuario;
- escolha de avatar/GIF;
- escolha de banner/GIF;
- ajuste de crop vertical do banner;
- exibicao de ID mascarado;
- logout local.

## O que fica para a proxima fatia

- autenticar contra o backend em vez de somente local;
- ligar `access token` e `refresh token`;
- keyring nativo do sistema quando for necessario endurecer o armazenamento local;
- upload remoto de avatar e banner;
- multiplos perfis por usuario.
