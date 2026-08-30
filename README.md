<p align="center">
  <img src="Assets/Brand/READMEHeader.svg" alt="SeguraMinhasNotas — macOS, Swift e licença MIT" width="100%">
</p>

<p align="center">
  <strong>Português do Brasil</strong> ·
  <a href="docs/README.en-US.md">English (United States)</a> ·
  <a href="docs/README.es-CO.md">Español (Colombia)</a>
</p>

<p align="center">
  Um baralho de notas rápidas na borda do Mac: nativo, local primeiro, sem conta e sem telemetria.
</p>

## Visão geral

O **SeguraMinhasNotas** é um aplicativo de código aberto para macOS. Ele deixa uma pequena pilha colorida na lateral da tela, quase invisível quando está em repouso. Ao levar o cursor até a borda, o baralho se abre; um clique transforma a nota em um editor flutuante.

O app foi escrito em Swift, SwiftUI e AppKit, exige macOS 13 ou posterior e não depende de servidor para criar, editar ou organizar notas. O conteúdo principal permanece no Mac e pode, opcionalmente, ser sincronizado por uma pasta escolhida pelo usuário.

## Tour visual

### Primeiros passos

<p align="center">
  <img src="docs/images/01-onboarding.png" alt="Tela inicial explicando como encontrar as notas na borda" width="620">
</p>

O onboarding apresenta o gesto da borda, a abertura do baralho, o editor com salvamento automático e os atalhos globais.

### Baralho lateral: em repouso e aberto

| Em repouso | Aberto em cascata |
|---|---|
| <img src="docs/images/02-deck-resting.png" alt="Baralho recolhido como pequenos traços coloridos" width="340"> | <img src="docs/images/03-deck-open.png" alt="Baralho de notas aberto na borda" width="340"> |

- Em repouso, apenas um traço de cada nota ocupa a borda.
- O baralho abre ao passar o cursor ou ao clicar, conforme a preferência.
- Até oito cartões aparecem diretamente; o restante fica acessível pela biblioteca.
- É possível manter o baralho aberto, trocar o lado da tela e arrastar cartões para reordenar.
- Cada monitor recebe seu próprio painel e o app pode acompanhar todos os Spaces e apps em tela cheia.

### Editor flutuante e checklists

<p align="center">
  <img src="docs/images/04-editor-checklists.png" alt="Editor flutuante com título, checklist, tags e cores" width="520">
</p>

O editor pode ser movido e redimensionado. Ele oferece título, texto, tags, checklists clicáveis, cinco cores, quatro estilos de fonte e tamanhos configuráveis. A nota é salva 250 ms depois que a digitação para. Uma nota fixada volta à mesa na próxima abertura do app.

### Biblioteca, busca, arquivo e exportação

<p align="center">
  <img src="docs/images/05-all-notes.png" alt="Biblioteca com busca, filtros, seleção múltipla, prévia e exportação" width="100%">
</p>

A janela **Todas as notas** reúne busca em título, corpo e tags, filtros para ativas e arquivadas, prévia, restauração, exclusão com 10 segundos para desfazer, importação e exportação em lote.

### Ajustes gerais e aparência

| Geral | Aparência |
|---|---|
| <img src="docs/images/06-settings-general.png" alt="Ajustes gerais do baralho e inicialização automática" width="520"> | <img src="docs/images/07-settings-appearance.png" alt="Ajustes de fonte, tamanho e prévia visual" width="520"> |

Em **Geral** ficam a inicialização automática, o comportamento em tela cheia, o lado da tela, o gesto de abertura e a velocidade das animações. Em **Aparência** ficam fonte, tamanho e uma prévia imediata.

### Sincronização e privacidade

| Sincronização | Privacidade |
|---|---|
| <img src="docs/images/08-settings-sync.png" alt="Sincronização opcional por uma pasta escolhida" width="520"> | <img src="docs/images/09-settings-privacy.png" alt="Ajustes de criptografia, autenticação e permissões" width="520"> |

A sincronização é opcional e trabalha com uma pasta do iCloud Drive, Dropbox ou outro provedor. A página de privacidade explica exatamente o que é cifrado, onde o arquivo fica, quando há acesso à rede e quais permissões o app não solicita.

### Atualizações e conteúdo protegido

| Sobre e atualizações | Notas bloqueadas |
|---|---|
| <img src="docs/images/10-settings-about.png" alt="Versão, licença e opções de atualização" width="520"> | <img src="docs/images/11-protected-notes.png" alt="Biblioteca bloqueada aguardando autenticação local" width="520"> |

O bloqueio opcional usa `LocalAuthentication`: Touch ID, Apple Watch ou a senha do próprio Mac. O aplicativo recebe somente o resultado da autenticação do sistema.

## O que o app pode fazer

| Área | Recursos |
|---|---|
| Painel lateral | Posição à esquerda ou à direita, um painel por monitor, repouso compacto, cascata animada e modo sempre aberto. |
| Notas | Editor flutuante, redimensionamento, pinagem, autosave de 250 ms, título, corpo, tags e cinco cores. |
| Checklists | Caixas clicáveis, continuação automática ao pressionar Enter e conversão correta para Markdown. |
| Organização | Busca sem diferenciar acentos, estados ativa/arquivada, restauração, reordenação e exclusão com desfazer. |
| Aparência | Fontes arredondada, do sistema, serifada ou monoespaçada e tamanho entre 13 e 28 pontos. |
| Idiomas | Português brasileiro, inglês americano e espanhol colombiano; a escolha acompanha o macOS e pode ser alterada por aplicativo. |
| Portabilidade | Importação, exportação em lote e arquivo completo de backup. |
| Sincronização | Uma nota legível por arquivo em qualquer pasta sincronizada escolhida pelo usuário. |
| Privacidade | Corpo local em AES-GCM, chave no Keychain, autenticação opcional e ausência de telemetria. |
| macOS | Atalhos globais, múltiplos monitores, Spaces, tela cheia, início automático e atualizações Sparkle. |

## Como usar

1. Abra o SeguraMinhasNotas. Ele funciona como aplicativo auxiliar e não ocupa espaço no Dock.
2. Leve o cursor até os pequenos traços coloridos na lateral da tela.
3. Clique em uma nota para abrir o editor ou no botão `+` para criar outra.
4. Use o menu de contexto do baralho para acessar todas as notas, o arquivo e os ajustes.
5. Ative **Abrir automaticamente ao ligar o Mac** se quiser que o baralho esteja disponível sempre que iniciar a sessão.

O macOS pode pedir que a ativação seja confirmada em **Ajustes do Sistema › Geral › Itens de Início**.

O idioma acompanha a preferência do macOS. Para escolher outro apenas no SeguraMinhasNotas, abra **Ajustes do Sistema › Geral › Idioma e Região › Aplicativos**, adicione o app e selecione **Português (Brasil)**, **English (US)** ou **Español (Colombia)**. Feche e abra o SeguraMinhasNotas para aplicar a mudança.

## Atalhos

| Ação | Atalho |
|---|---|
| Nova nota | `⌥⌘N` |
| Todas as notas | `⌥⌘A` |
| Arquivo | `⌥⌘L` |
| Fechar o editor atual | `⌘W` |

Os atalhos são registrados pelas APIs nativas do macOS e não exigem permissão de Acessibilidade ou monitoramento de entrada.

## Importação e exportação

### Exportar

- **Markdown:** um arquivo `.md` por nota, preservando checklists.
- **Texto simples:** um `.txt` por nota.
- **Documento único:** todas as notas em um único arquivo Markdown.
- **Arquivo SeguraMinhasNotas:** pacote `.seguranotas` para backup e restauração.
- **Arquivo portátil:** pacote estruturado `.stickies` do projeto.

### Importar

- arquivos `.seguranotas` e `.stickies`;
- Markdown e texto simples;
- RTF e pacotes RTFD exportados pelo Stickies;
- pastas contendo vários arquivos compatíveis.

## Dados, sincronização e privacidade

O armazenamento principal fica em:

```text
~/Library/Application Support/SeguraMinhasNotas/notes.json
```

- O **corpo** de cada nota é cifrado com AES-GCM.
- A chave aleatória de 256 bits fica no Keychain e não é marcada como sincronizável.
- Título, tags, cor e metadados de ciclo de vida permanecem legíveis no envelope local para indexação e recuperação.
- Não há analytics, telemetria ou crash reporting integrado.
- A rede é usada pelo Sparkle para consultar o feed de atualização. A sincronização ocorre pela pasta que você escolheu, não por um servidor do projeto.
- Os arquivos `.seguranota` da sincronização por pasta são propositalmente legíveis para portabilidade; não use uma pasta cuja política de privacidade você desconheça.
- O bloqueio pode ocultar tudo quando a tela do Mac é bloqueada e exigir autenticação local ao voltar.

Consulte [SECURITY.md](SECURITY.md) para o modelo de segurança e o canal de relato de vulnerabilidades.

## Requisitos e instalação

### Requisitos

- macOS 13 Ventura ou posterior;
- Mac com Apple Silicon ou Intel suportado pelo toolchain usado no build;
- para compilar: Swift 6 e Command Line Tools do Xcode.

### Compilar do código-fonte

```bash
git clone https://github.com/lrqnet/SeguraMinhasNotas.git
cd seguraminhasnotas
./scripts/check.sh
./scripts/build-app.sh
open .build/SeguraMinhasNotas.app
```

O primeiro build baixa o Sparkle pelo Swift Package Manager. O bundle local recebe assinatura ad hoc, adequada para desenvolvimento local.

## Arquitetura

| Componente | Implementação |
|---|---|
| Interface | SwiftUI para as telas e AppKit para painéis, janelas flutuantes e integração com o macOS. |
| Estado | `NoteStore` observável, operações no `MainActor` e persistência serializada fora da interface. |
| Persistência | Envelope JSON com corpo AES-GCM e chave armazenada no Keychain. |
| Autenticação | `LocalAuthentication` com a política de proprietário do dispositivo. |
| Início automático | `SMAppService.mainApp`; o estado e a aprovação pertencem ao macOS. |
| Atualizações | Sparkle 2.9.6; releases públicas devem ser assinadas. |
| Distribuição | Swift Package Manager, bundle `.app`, assinatura Apple e arquivo `.zip`. |

O app usa `LSUIElement`, por isso se comporta como utilitário de fundo sem ícone permanente no Dock. O código-fonte fica em [`Sources/SeguraMinhasNotas`](Sources/SeguraMinhasNotas).

## Desenvolvimento e validação

Execute as verificações locais:

```bash
./scripts/check.sh
./scripts/build-app.sh
codesign --verify --deep --strict --verbose=2 .build/SeguraMinhasNotas.app
```

Leia [CONTRIBUTING.md](CONTRIBUTING.md) antes de enviar uma alteração.

## Autoria

Criado e mantido por [Lucas Quaresma](https://github.com/lrqnet).

## Licença MIT

Este projeto é software livre sob a [licença MIT](LICENSE). Em termos práticos, qualquer pessoa pode:

- usar o código para fins pessoais ou comerciais;
- copiar, modificar e combinar com outros projetos;
- publicar e distribuir versões originais ou alteradas;
- sublicenciar ou vender cópias do software.

A única condição principal é manter o aviso de copyright e o texto da licença nas cópias ou partes substanciais. O software é fornecido **sem garantia**. Ou seja: sim, você pode copiar, adaptar e construir o que quiser em cima dele, inclusive comercialmente, respeitando esse aviso.
