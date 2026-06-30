# AppHealthFlutter — Aplicativo de bafômetros (Health Safety)

App **Flutter** que faz teste de alcoolemia conectando-se via **Bluetooth BLE** a bafômetros, registra os resultados por funcionário e gera histórico/laudos. Pacote Android: `com.healthsafety.app`. Multiplataforma no repositório (android/ios/web/linux/macos/windows), mas o alvo real é **Android**.

> ⚠️ Documento de orientação. Antes de mexer, ver a seção **"Estado conhecido / cuidados"**. Há um bug ativo na descoberta BLE do aparelho Titan.

## O que o app faz (3 pilares)

1. **Conectar via BLE** a dois tipos de aparelho:
   - **iBlow / AL88** (nomes BLE: `IBLOW`, `AL88`)
   - **Titan / Deimos** (nome BLE: `HLX-...`, ex. `HLX-BLE-18`; também `DEIMOS`)
2. **Enviar comandos e receber dados** do aparelho (iniciar teste, ler resultado de álcool, bateria, firmware, calibração).
3. **Salvar os testes** realizados (resultado + funcionário + foto opcional + metadados) e permitir histórico, laudo PDF e exportação.

A escolha entre iBlow e Titan é **implícita pelo nome do dispositivo conectado** — não há tela de seleção de modelo. A detecção por nome é repetida em vários pontos (ver "Pegadinhas").

## Stack / dependências principais

| Área | Lib | Versão |
|---|---|---|
| BLE | `flutter_blue_plus` | ^1.31.15 |
| Estado | `flutter_riverpod` | 2.6.1 (`StateNotifierProvider`) |
| Persistência (dados) | `hive` / `hive_flutter` | ^2.2.3 / ^1.1.0 |
| Persistência (configs) | `shared_preferences` | — |
| Câmera | `camera` | — |
| PDF / laudo | `pdf`, `printing` | ^3.10.4 |
| Excel | `syncfusion_flutter_xlsio` | ^28.2.12 |
| Compartilhar | `share_plus` | — |
| Codegen Hive | `build_runner`, `hive_generator` | dev |

Dart `^3.7.0`, canal `stable`. (`.g.dart` são gerados pelo `build_runner` — não editar à mão.)

## Arquitetura em camadas

```
UI (screens/, widgets/)
   └─ consome Riverpod ──────────────┐
providers/                           │
   bluetooth_provider.dart  ← estado central do BLE + processa testes e salva
   historico_provider.dart  ← grava/lê testes no Hive (box 'testes' / 'favoritos')
   funcionario_provider.dart, configuracoes_provider.dart, auth_provider.dart
services/
   bluetooth_manager.dart   ← ESCOLHE o handler por nome do device
   bluetooth_scan_service.dart ← scan BLE (filtra AL88/IBLOW/HLX/DEIMOS)
   handlers/
     bluetooth_handler.dart        ← interface base
     al88_iblow_handler.dart       ← protocolo iBlow (✅ ok)
     titan_deimos_handler.dart     ← protocolo Titan (⚠️ ver bug)
models/  test_model.dart, funcionario_model.dart, device_info.dart (+ .g.dart)
```

### Caminho dos dados (resumo)
`handler` (parseia bytes do aparelho) → callback `onData(parsed)` → `BluetoothManager` → `BluetoothNotifier.onDataFromHandler()` (`bluetooth_provider.dart`) → `_processarTeste()` → monta `TestModel` → `historicoProvider.adicionarTeste()` → grava no Hive.

## Os dois aparelhos (diferenças de protocolo)

| Aspecto | **iBlow / AL88** | **Titan / Deimos (HLX)** |
|---|---|---|
| Serviço/característica BLE | descoberta por **propriedade** + substring `fff2` | **Nordic UART** fixo: serviço `6e400001…`, escrita(TX) `6e400002…`, notif(RX) `6e400003…`, CCCD `2902` |
| Pacote | fixo **20 bytes** ASCII: `0x02`(STX) + cmd(3) + dados(14, padding `#`) + BCC + `0x03`(ETX) | frame variável: `0x68` + addr(6) + `0x68` + control + len(LE,2) + payload + checksum + `0x16` |
| Checksum | BCC (`(0x10000 - soma) % 256`) | soma simples mod 256 |
| Handshake | nenhum (pronto após descobrir características) | **obrigatório**: envia `FF02` (broadcast) → recebe endereço real → envia `FF04`=01. Sem isso, comandos são bloqueados |
| Iniciar teste | `A20` + `TEST,START` | `9002` + `START` |
| Resultado | comando `T11`/`A20`, dados ASCII `"a,b,c,…"` | comando `9003`, `(valH*256+valL)/100` mg/100ml |
| Status de sopro | `T06`/`T07` (Soprar/Assoprando) | `9002` status byte: 1=soprar, 2=fim, 3=descont., 4=recusa, 5=cálculo, 6=calib |
| Firmware/uso/calibração | `A01` / `A03` / `A04` | `FF00` / `9005` / `9007` (+ bateria `9004`) |
| Buffer RX | não (pacote inteiro) | **sim** (acumula fragmentos até `0x16`) |
| Momento da foto | **depois** do resultado (T11) | **antes** do resultado (ao receber `9002` status 2) |

Especificação completa do Titan: `protocolo de comunicação.txt` e `Titan bluetooth communication protocol.pdf` (raiz do repo).

## Fluxo de um teste (visão do usuário)

1. Aba **Principal** (`home_screen.dart`): escaneia, lista aparelhos (nome+ID), conecta.
2. Seleciona funcionário (ou "Visitante").
3. "Iniciar Teste" → envia comando de início conforme o aparelho.
4. Se `fotoAtivada`: abre a câmera; a foto é capturada automaticamente quando o estado `precisaCapturarFoto` dispara (momento difere entre iBlow e Titan — ver tabela).
5. Aparelho devolve progresso de sopro e depois o resultado; `_processarTeste()` monta o `TestModel`.
6. `salvarTesteComFoto()` associa a foto e grava no histórico (Hive).
7. Abas **Histórico** (lista/favoritos/detalhe+foto, exporta) e **Dispositivo** (`informacoes_dispositivo_screen.dart`: info do aparelho, restaura conexão, listener de notificações).

## Modelos e persistência (Hive)

Boxes abertas em `main.dart` (`Hive.initFlutter` + `registerAdapter`): **`testes`** (`TestModel`), **`funcionarios`** (`FuncionarioModel`), **`favoritos`** (chave→marcador).

**`TestModel`** (`models/test_model.dart`): `timestamp` (DateTime, usado como **chave** do box), `command` (resultado, ex. `"0.05 mg/L"`), `statusCalibracao`, `batteryLevel`, `funcionarioId?`, `funcionarioNome`, `photoPath?`, `isFavorito`, `deviceName?`. Helpers de cor por resultado (verde/amarelo/vermelho) e `isAcimaDaTolerancia()`.

**`FuncionarioModel`**: `id` (timestamp ms), `nome`, `cargo`, `cpf?`, `matricula?`, `informacao1?`, `informacao2?`.

`historico_provider.adicionarTeste()`: grava no box `testes`; se acima da **tolerância** (config, padrão 0.05) marca **favorito** automaticamente.

Configs em **SharedPreferences** (`configuracoes_provider`): `fotoAtivada` (padrão true), `tolerancia` (0.05), `exibirStatusCalibracao`, `notificacoesAtivas`. Tema (`theme_provider`) e auth (`auth_provider`, `ChangeNotifier`) também em SharedPreferences.

Exportação: `export_helper.dart` (ZIP/PDF/XLS via Syncfusion+share_plus) e `laudo_pdf_helper.dart` (laudo individual com logo, dados, foto e assinaturas). `funcionario_excel_helper.dart` está **vazio** (não implementado).

## Estado conhecido / cuidados ⚠️

- **BUG ATIVO — escrita BLE do Titan vem `null`.** Em runtime (aparelho `HLX-BLE-18`), a característica de **notificação** `6e400003` é encontrada e ativada, mas a de **escrita** `6e400002` fica `null`, disparando *"Dispositivo não conectado ou característica de escrita indisponível"*. Sem ela o app **recebe** mas **não envia** comandos ao Titan.
  - Local: `services/handlers/titan_deimos_handler.dart:104-123` (`discoverCharacteristics`). Usa **igualdade exata** `uuid == txCharUuid` e **não** verifica `properties.write`.
  - Compare com `al88_iblow_handler.dart:78-93`, que usa `contains()` + checagem de `properties.write/writeWithoutResponse` (e funciona).
  - Causa ainda **não confirmada** (pode ser o aparelho não expor `6e400002`, expor a escrita sob outro UUID, ou ordem de descoberta). **Investigar com os logs reais de `[TitanDeimosHandler] Característica encontrada:` antes de alterar.**
- **Arquivos de backup no repo — NÃO usar/editar como se fossem ativos:** `bluetooth_manager antigo.dart`, `handlers/titan_deimos_handler antigo.dart`, `handlers/titan_deimos_handler errado.dart`. Só os sem sufixo estão no fluxo.
- **Detecção de aparelho duplicada:** a lógica `name.contains("iblow"/"al88"/"hlx"/"deimos")` aparece em **vários lugares** (`bluetooth_manager.dart`, `bluetooth_provider.dart`, `home_screen.dart`, `informacoes_dispositivo_screen.dart`). Mudança no critério precisa ser replicada em todos.
- `Health_App.apk` versionado na raiz é build **antiga** (pacote placeholder `com.example.Health_App`), não reflete o código atual.
- Logs do app saem com tag **`flutter`** (`adb logcat -s flutter`); o código tem muito `print()` com emojis, útil pra depurar o BLE.

## Build / execução

Toolchain e passos completos estão documentados na máquina (memória do assistente: *AppHealthFlutter — setup Android*). Resumo:

```bash
export PATH="$HOME/development/flutter/bin:$HOME/Android/Sdk/platform-tools:$PATH"
flutter pub get
flutter build apk --debug   # precisa de android/key.properties (fora do git) — já criado localmente
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

Gerar adapters Hive após mudar models: `flutter pub run build_runner build --delete-conflicting-outputs`.
