# Design — Blindagem do `writable=null` na conexão/reconexão BLE do Titan

**Data:** 2026-06-30
**Escopo:** Robustez BLE focada (defense-in-depth). Corrigir o bug intermitente em que a característica de escrita do aparelho Titan/Deimos (HLX) fica `null`, impedindo o envio de comandos. **iBlow/AL88 não é tocado** (confirmado correto pelo usuário).

## Contexto e problema

O aparelho Titan usa o serviço Nordic UART (`6e400001-...`) com:
- `6e400003` → notificação (`notify=true`)
- `6e400002` → escrita (`write=true`, `writeWithoutResponse=true`)

Em runtime observou-se, de forma **intermitente e não reproduzível sob demanda**, a mensagem *"Dispositivo não conectado ou característica de escrita indisponível"* com `writable=null` chegando ao `BluetoothManager`. Numa conexão limpa (Bluetooth do aparelho religado) a descoberta funciona e `6e400002` é encontrada normalmente (confirmado por dump completo da tabela GATT). A falha está associada ao caminho de **reconexão/restauração** (handler reaproveitado, `BluetoothHandler já inicializado`).

Como a falha não é reproduzível sob demanda, a estratégia é **defense-in-depth**: blindar todas as camadas por onde o `null` pode passar, sem alterar o comportamento de sucesso atual.

## Causa(s) identificada(s) por análise estática

1. **Snapshot de estado desatualizado** em `informacoes_dispositivo_screen.dart` → `_restaurarConexao()`:
   - Linha ~78: `final bluetoothState = ref.read(bluetoothProvider);` captura o estado **antes** da redescoberta.
   - Linha ~90: `await bluetoothNotifier.restoreCharacteristics();` cria um **novo** objeto de estado (Riverpod é imutável).
   - Linhas ~93/104: continuam lendo o snapshot **antigo** → avaliam características de forma desatualizada (gera "indisponível" intermitente conforme o estado no instante da foto).

2. **Descoberta só-por-UUID-exato** no Titan (`titan_deimos_handler.dart:104-123`): usa `uuid == txCharUuid`/`rxCharUuid`, sem fallback por propriedade. Menos robusto que o iBlow (`al88_iblow_handler.dart:74-93`), que combina UUID + verificação de `write/writeWithoutResponse`/`notify`. Frágil a variações de enumeração/ordem.

3. **`setCharacteristics` mantém estado obsoleto** (`bluetooth_provider.dart:142-159`): só atualiza `writable` quando `!= null`. Se a descoberta devolver `null`, o estado mantém o valor anterior (que pode ser `null`), e nunca se recupera sozinho.

## Solução (defense-in-depth, 3 camadas)

### Camada 1 — Handler Titan (`titan_deimos_handler.dart`, `discoverCharacteristics`)
Tornar a seleção de características **UUID preferencial + fallback por propriedade**, espelhando o iBlow:
- `writable`: selecionar a característica cujo `uuid == txCharUuid`; se nenhuma bater, escolher a primeira dentro do serviço UART com `properties.write || properties.writeWithoutResponse`.
- `notifiable`: selecionar `uuid == rxCharUuid`; fallback para a primeira com `properties.notify`.
- Manter a ativação de notificações/descritor `2902` e o handshake existentes inalterados.
- Ao final, se `_writableCharacteristic == null`, emitir **log de aviso** listando as características encontradas (UUID + propriedades), para diagnóstico futuro.

### Camada 2 — Provider (`bluetooth_provider.dart`)
- Após a descoberta (em `restoreCharacteristics()` e `connectToDevice()`), se `state.writableCharacteristic == null` porém `_bluetoothManager.writableCharacteristic != null`, **adotar a do handler** via `setCharacteristics`.
- Se ainda faltar e `state.connectedDevice != null`, executar **um único retry** de `discoverCharacteristics`. Sem loops; no máximo 1 tentativa extra.
- Não alterar a assinatura pública dos métodos; mudanças internas.

### Camada 3 — Tela Dispositivo (`informacoes_dispositivo_screen.dart`, `_restaurarConexao`)
- **Reler o estado após** `await restoreCharacteristics()`: substituir os usos do snapshot antigo por uma nova leitura `ref.read(bluetoothProvider)` (ou ler do `notifier`), de modo que as verificações de `notifiableCharacteristic`/`writableCharacteristic` reflitam o estado atualizado.

## Não-objetivos (YAGNI)
- Não mexer no iBlow/AL88.
- Não refatorar a detecção de aparelho duplicada, nem remover arquivos `antigo`/`errado`, nem o APK versionado (fora do escopo desta rodada).
- Não adicionar testes automatizados (exigiria mockar `flutter_blue_plus`); validação é manual no aparelho.

## Tratamento de erro
- Nenhuma exceção nova. Todos os caminhos de falha continuam logando e retornando como hoje, agora com fallback antes de desistir.
- Comportamento da **conexão limpa permanece idêntico**; o fallback/retry só atua quando o fluxo atual resultaria em `null`.

## Verificação (manual, no aparelho)
1. Build debug + instalar.
2. Ciclos de: conectar → desconectar → reconectar; alternar abas (Principal ↔ Dispositivo) algumas vezes; reabrir o app.
3. Confirmar via `adb logcat -s flutter` que a característica de escrita é sempre resolvida (sem "escrita indisponível") e que um teste de álcool envia comandos e salva normalmente.
4. Conferir que o resultado continua correto (conversão `/210` já validada).

## Arquivos afetados
- `lib/services/handlers/titan_deimos_handler.dart` (Camada 1)
- `lib/providers/bluetooth_provider.dart` (Camada 2)
- `lib/screens/informacoes_dispositivo_screen.dart` (Camada 3)
