# Blindagem do `writable=null` no BLE do Titan — Plano de Implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Eliminar o bug intermitente em que a característica de escrita do Titan/Deimos fica `null`, blindando descoberta, estado e tela (defense-in-depth), sem alterar o comportamento da conexão limpa.

**Architecture:** Três mudanças isoladas, uma por camada — (1) descoberta por UUID+propriedade no handler Titan, (2) fallback/retry no provider, (3) releitura de estado na tela Dispositivo. Cada uma é independente e auto-contida.

**Tech Stack:** Flutter 3.44.4, Dart 3.12.2, flutter_blue_plus ^1.31.15, Riverpod (StateNotifier).

## Global Constraints

- **NÃO tocar no iBlow/AL88** (`al88_iblow_handler.dart`) — confirmado correto.
- **Comportamento da conexão limpa deve permanecer idêntico**; mudanças só agregam fallback quando o fluxo atual resultaria em `null`.
- **Sem testes automatizados** (BLE dependente de hardware; mockar `flutter_blue_plus` está fora do escopo). Verificação por arquivo = `flutter analyze <arquivo>` sem erros; verificação funcional = manual no aparelho (Task 4).
- **Build/PATH:** sempre `export PATH="$HOME/development/flutter/bin:$HOME/Android/Sdk/platform-tools:$PATH"` antes de `flutter ...`.
- **Build de APK precisa de `android/key.properties`** (já existe localmente, fora do git).
- **Mensagens de commit** terminam com: `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`.
- Diretório do projeto: `~/github/AppHealthFlutter`.

## File Structure

- `lib/services/handlers/titan_deimos_handler.dart` — Camada 1 (descoberta robusta). Responsável por falar o protocolo do Titan; aqui mexemos só no `discoverCharacteristics`.
- `lib/providers/bluetooth_provider.dart` — Camada 2 (fallback/retry de estado). Responsável pelo estado BLE central e por repassar características à UI.
- `lib/screens/informacoes_dispositivo_screen.dart` — Camada 3 (releitura de estado). Tela "Dispositivo" que restaura a conexão ao ser exibida.

---

### Task 1: Descoberta robusta no handler Titan (Camada 1)

**Files:**
- Modify: `lib/services/handlers/titan_deimos_handler.dart` (dentro de `discoverCharacteristics`, laço de varredura de serviços, hoje ~linhas 104-123)

**Interfaces:**
- Consumes: campos existentes `_writableCharacteristic`, `_notifiableCharacteristic`; constantes `uartServiceUuid`, `txCharUuid`, `rxCharUuid`.
- Produces: nenhuma assinatura nova; após este laço, `_writableCharacteristic`/`_notifiableCharacteristic` ficam preenchidos por UUID exato OU por propriedade.

- [ ] **Step 1: Substituir o laço de varredura por versão com fallback por propriedade**

Localize o bloco atual:

```dart
    for (BluetoothService service in services) {
      print('[TitanDeimosHandler] Serviço: ${service.uuid}');
      if (service.uuid.toString().toLowerCase() == uartServiceUuid) {
        for (BluetoothCharacteristic c in service.characteristics) {
          final uuid = c.uuid.toString().toLowerCase();
          print('[TitanDeimosHandler] Característica encontrada: ${uuid}');
          if (uuid == txCharUuid) {
            _writableCharacteristic = c;
            print(
              '[TitanDeimosHandler] Característica de escrita selecionada: ${c.uuid}',
            );
          } else if (uuid == rxCharUuid) {
            _notifiableCharacteristic = c;
            print(
              '[TitanDeimosHandler] Característica de notificação selecionada: ${c.uuid}',
            );
          }
        }
      }
    }
```

Substitua por:

```dart
    BluetoothCharacteristic? writablePorPropriedade;
    BluetoothCharacteristic? notifiablePorPropriedade;
    for (BluetoothService service in services) {
      print('[TitanDeimosHandler] Serviço: ${service.uuid}');
      if (service.uuid.toString().toLowerCase() == uartServiceUuid) {
        for (BluetoothCharacteristic c in service.characteristics) {
          final uuid = c.uuid.toString().toLowerCase();
          final p = c.properties;
          print('[TitanDeimosHandler] Característica encontrada: ${uuid}');
          // Preferencial: UUID exato
          if (uuid == txCharUuid) {
            _writableCharacteristic = c;
            print(
              '[TitanDeimosHandler] Característica de escrita selecionada: ${c.uuid}',
            );
          } else if (uuid == rxCharUuid) {
            _notifiableCharacteristic = c;
            print(
              '[TitanDeimosHandler] Característica de notificação selecionada: ${c.uuid}',
            );
          }
          // Fallback por propriedade (primeira que servir)
          if (writablePorPropriedade == null &&
              (p.write || p.writeWithoutResponse)) {
            writablePorPropriedade = c;
          }
          if (notifiablePorPropriedade == null && p.notify) {
            notifiablePorPropriedade = c;
          }
        }
      }
    }
    // Usa o fallback se o UUID exato não apareceu
    if (_writableCharacteristic == null && writablePorPropriedade != null) {
      _writableCharacteristic = writablePorPropriedade;
      print(
        '[TitanDeimosHandler] Escrita via fallback por propriedade: ${_writableCharacteristic!.uuid}',
      );
    }
    if (_notifiableCharacteristic == null && notifiablePorPropriedade != null) {
      _notifiableCharacteristic = notifiablePorPropriedade;
      print(
        '[TitanDeimosHandler] Notificação via fallback por propriedade: ${_notifiableCharacteristic!.uuid}',
      );
    }
    // Diagnóstico se ainda faltar a escrita
    if (_writableCharacteristic == null) {
      print(
        '[TitanDeimosHandler] ⚠️ Característica de escrita NÃO encontrada. Disponíveis:',
      );
      for (final s in services) {
        for (final c in s.characteristics) {
          final p = c.properties;
          print(
            '   ${s.uuid}/${c.uuid} write=${p.write} '
            'writeNoResp=${p.writeWithoutResponse} notify=${p.notify}',
          );
        }
      }
    }
```

- [ ] **Step 2: Verificar que compila sem erros**

Run:
```bash
cd ~/github/AppHealthFlutter
export PATH="$HOME/development/flutter/bin:$HOME/Android/Sdk/platform-tools:$PATH"
flutter analyze lib/services/handlers/titan_deimos_handler.dart
```
Expected: nenhum erro `error •` (avisos `info • avoid_print` pré-existentes são aceitáveis).

- [ ] **Step 3: Commit**

```bash
cd ~/github/AppHealthFlutter
git add lib/services/handlers/titan_deimos_handler.dart
git commit -m "fix(titan): descoberta de característica por UUID + propriedade (fallback)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: Fallback + retry de característica de escrita no provider (Camada 2)

**Files:**
- Modify: `lib/providers/bluetooth_provider.dart` (`connectToDevice` ~127-139, `restoreCharacteristics` ~466-477; adicionar método privado novo)

**Interfaces:**
- Consumes: `_bluetoothManager.writableCharacteristic` e `_bluetoothManager.notifiableCharacteristic` (getters já existentes em `BluetoothManager`); `setCharacteristics({writable, notifiable})`; `state.writableCharacteristic`, `state.connectedDevice`.
- Produces: método privado `Future<void> _garantirCaracteristicaEscrita()` chamado ao fim das descobertas.

- [ ] **Step 1: Adicionar o método auxiliar `_garantirCaracteristicaEscrita`**

Logo após o método `restoreCharacteristics()` (depois da sua chave de fechamento `}`), insira:

```dart
  /// 🔹 Garante a característica de escrita no estado.
  /// 1) Fallback: adota a do handler se o estado estiver sem.
  /// 2) Retry único de descoberta se ainda faltar e o device estiver conectado.
  Future<void> _garantirCaracteristicaEscrita() async {
    if (state.writableCharacteristic == null &&
        _bluetoothManager.writableCharacteristic != null) {
      print(
        "♻️ [bluetoothProvider] Adotando característica de escrita do handler (fallback).",
      );
      setCharacteristics(
        writable: _bluetoothManager.writableCharacteristic,
        notifiable: _bluetoothManager.notifiableCharacteristic,
      );
    }

    if (state.writableCharacteristic == null && state.connectedDevice != null) {
      print(
        "🔁 [bluetoothProvider] Escrita ainda ausente — 1 retry de descoberta...",
      );
      await _bluetoothManager.discoverCharacteristics(state.connectedDevice!, (
        writable,
        notifiable,
      ) {
        setCharacteristics(writable: writable, notifiable: notifiable);
      });
      if (state.writableCharacteristic == null &&
          _bluetoothManager.writableCharacteristic != null) {
        setCharacteristics(
          writable: _bluetoothManager.writableCharacteristic,
          notifiable: _bluetoothManager.notifiableCharacteristic,
        );
      }
    }
  }
```

- [ ] **Step 2: Chamar o auxiliar ao fim de `restoreCharacteristics`**

Localize:

```dart
  Future<void> restoreCharacteristics() async {
    if (state.connectedDevice != null) {
      print("♻️ Restaurando características BLE...");
      await _bluetoothManager.discoverCharacteristics(state.connectedDevice!, (
        writable,
        notifiable,
      ) {
        setCharacteristics(writable: writable, notifiable: notifiable);
        listenToNotifications();
      });
    }
  }
```

Substitua por (adiciona `await _garantirCaracteristicaEscrita();`):

```dart
  Future<void> restoreCharacteristics() async {
    if (state.connectedDevice != null) {
      print("♻️ Restaurando características BLE...");
      await _bluetoothManager.discoverCharacteristics(state.connectedDevice!, (
        writable,
        notifiable,
      ) {
        setCharacteristics(writable: writable, notifiable: notifiable);
        listenToNotifications();
      });
      await _garantirCaracteristicaEscrita();
    }
  }
```

- [ ] **Step 3: Aguardar a descoberta e chamar o auxiliar em `connectToDevice`**

Localize:

```dart
  Future<bool> connectToDevice(BluetoothDevice device) async {
    bool success = await _bluetoothManager.connectToDevice(device);
    if (success) {
      state = state.copyWith(isConnected: true, connectedDevice: device);

      // ✅ Agora usamos a função de callback para atualizar características BLE
      _bluetoothManager.discoverCharacteristics(device, (writable, notifiable) {
        setCharacteristics(writable: writable, notifiable: notifiable);
        listenToNotifications();
      });
    }
    return success;
  }
```

Substitua por (adiciona `await` na descoberta e chama o auxiliar):

```dart
  Future<bool> connectToDevice(BluetoothDevice device) async {
    bool success = await _bluetoothManager.connectToDevice(device);
    if (success) {
      state = state.copyWith(isConnected: true, connectedDevice: device);

      // ✅ Agora usamos a função de callback para atualizar características BLE
      await _bluetoothManager.discoverCharacteristics(device, (
        writable,
        notifiable,
      ) {
        setCharacteristics(writable: writable, notifiable: notifiable);
        listenToNotifications();
      });
      await _garantirCaracteristicaEscrita();
    }
    return success;
  }
```

- [ ] **Step 4: Verificar que compila sem erros**

Run:
```bash
cd ~/github/AppHealthFlutter
export PATH="$HOME/development/flutter/bin:$HOME/Android/Sdk/platform-tools:$PATH"
flutter analyze lib/providers/bluetooth_provider.dart
```
Expected: nenhum erro `error •` (avisos `info` pré-existentes ok).

- [ ] **Step 5: Commit**

```bash
cd ~/github/AppHealthFlutter
git add lib/providers/bluetooth_provider.dart
git commit -m "fix(ble): fallback + retry da característica de escrita no provider

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: Releitura de estado na tela Dispositivo (Camada 3)

**Files:**
- Modify: `lib/screens/informacoes_dispositivo_screen.dart` (`_restaurarConexao`, ~76-110)

**Interfaces:**
- Consumes: `ref.read(bluetoothProvider)` (estado atualizado pós-restauração); `notifiableCharacteristic`.
- Produces: nenhuma; corrige leitura para usar estado fresco.

- [ ] **Step 1: Reler o estado após `restoreCharacteristics()`**

Localize o trecho a partir de `await bluetoothNotifier.restoreCharacteristics();`:

```dart
    await bluetoothNotifier.restoreCharacteristics();
    await Future.delayed(const Duration(seconds: 1));

    if (bluetoothState.notifiableCharacteristic == null) {
      print(
        "❌ [InformacoesDispositivoScreen] Característica de notificação ainda não disponível!",
      );
      return;
    }

    print(
      "🔍 [InformacoesDispositivoScreen] Característica de notificação confirmada: ${bluetoothState.notifiableCharacteristic!.uuid}",
    );

    await bluetoothState.notifiableCharacteristic!.setNotifyValue(true);
    print("✅ [InformacoesDispositivoScreen] Notificações BLE ativadas!");
```

Substitua por (relê em `estadoAtual` e usa essa variável):

```dart
    await bluetoothNotifier.restoreCharacteristics();
    await Future.delayed(const Duration(seconds: 1));

    // Relê o estado APÓS a restauração — o snapshot inicial ficou
    // desatualizado (Riverpod é imutável; restoreCharacteristics criou
    // um novo objeto de estado).
    final estadoAtual = ref.read(bluetoothProvider);

    if (estadoAtual.notifiableCharacteristic == null) {
      print(
        "❌ [InformacoesDispositivoScreen] Característica de notificação ainda não disponível!",
      );
      return;
    }

    print(
      "🔍 [InformacoesDispositivoScreen] Característica de notificação confirmada: ${estadoAtual.notifiableCharacteristic!.uuid}",
    );

    await estadoAtual.notifiableCharacteristic!.setNotifyValue(true);
    print("✅ [InformacoesDispositivoScreen] Notificações BLE ativadas!");
```

- [ ] **Step 2: Verificar que compila sem erros**

Run:
```bash
cd ~/github/AppHealthFlutter
export PATH="$HOME/development/flutter/bin:$HOME/Android/Sdk/platform-tools:$PATH"
flutter analyze lib/screens/informacoes_dispositivo_screen.dart
```
Expected: nenhum erro `error •` (avisos `info` pré-existentes ok).

- [ ] **Step 3: Commit**

```bash
cd ~/github/AppHealthFlutter
git add lib/screens/informacoes_dispositivo_screen.dart
git commit -m "fix(tela-dispositivo): relê estado BLE após restaurar conexão

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: Build e verificação no aparelho (manual)

**Files:** nenhum (apenas build + teste em hardware).

**Interfaces:** N/A.

- [ ] **Step 1: Build debug + instalar**

Run:
```bash
cd ~/github/AppHealthFlutter
export PATH="$HOME/development/flutter/bin:$HOME/Android/Sdk/platform-tools:$PATH"
flutter build apk --debug
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```
Expected: `✓ Built build/app/outputs/flutter-apk/app-debug.apk` e `Success`.

- [ ] **Step 2: Capturar logs durante o teste de reconexão**

Run (em um terminal, deixe rodando):
```bash
~/Android/Sdk/platform-tools/adb logcat -c
~/Android/Sdk/platform-tools/adb logcat -s flutter
```

No aparelho, repetir algumas vezes: conectar no HLX → desconectar → reconectar; alternar abas **Principal ↔ Dispositivo**; reabrir o app já conectado.

- [ ] **Step 3: Validar o comportamento**

Confirmar nos logs/uso:
- A característica de escrita é sempre resolvida (mensagens de seleção/fallback aparecem; **não** aparece "característica de escrita indisponível").
- Um teste de álcool envia comandos e salva normalmente, com o valor correto (conversão `/210` já validada).

Se o `writable` ainda faltar em algum ciclo, o log "⚠️ Característica de escrita NÃO encontrada. Disponíveis:" (Task 1) lista a tabela GATT para diagnóstico — reportar.

- [ ] **Step 4 (opcional): Push**

```bash
cd ~/github/AppHealthFlutter
git push
```

---

## Self-Review

- **Cobertura do spec:** Camada 1 → Task 1; Camada 2 → Task 2; Camada 3 → Task 3; verificação manual → Task 4. iBlow não tocado ✓. Log de diagnóstico presente (Task 1, Step 1) ✓.
- **Placeholders:** nenhum TBD/TODO; todo passo de código tem o bloco completo.
- **Consistência de tipos/nomes:** `_garantirCaracteristicaEscrita()` definido na Task 2 e chamado nas duas localizações da mesma task; getters `writableCharacteristic`/`notifiableCharacteristic` conferem com `BluetoothManager`/`BluetoothHandler`; `setCharacteristics({writable, notifiable})` com nomes de parâmetro corretos; `estadoAtual` usado de forma consistente na Task 3.
