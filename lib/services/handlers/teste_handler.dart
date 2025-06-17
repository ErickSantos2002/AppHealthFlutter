import 'dart:convert';

void main() {
  // Frame de exemplo em hexadecimal
  List<int> frame = [
    0x68, 0x30, 0x30, 0x30, 0x30, 0x27, 0x10, 0x68,
    0x81, 0x08, 0x00, 0x07, 0x90, 0x24, 0x07,
    0x16, 0x14, 0x42, 0x17, 0x95, 0x16
  ];

  final result = processCompleteFrame(frame);
  print('Resultado:\n$result');
}

Map<String, dynamic>? processCompleteFrame(List<int> data) {
  if (data.length < 12 || data[0] != 0x68 || data[7] != 0x68 || data.last != 0x16) {
    print('Frame inválido!');
    return null;
  }

  int length = data[9] + (data[10] << 8);
  int payloadStart = 11;
  int payloadEnd = payloadStart + length;
  int checksumPos = data.length - 2;

  if (data.length < payloadEnd + 2) {
    print('Tamanho do frame menor que esperado.');
    return null;
  }

  List<int> payload = data.sublist(payloadStart, payloadEnd);
  int receivedChecksum = data[checksumPos];

  int calculatedChecksum = data.sublist(0, checksumPos).fold(0, (sum, b) => (sum + b) & 0xFF);
  if (receivedChecksum != calculatedChecksum) {
    print('Checksum inválido. Recebido: $receivedChecksum, Calculado: $calculatedChecksum');
    return null;
  }

  int control = data[8];
  if (control == 0x81 && payload.length >= 2) {
    int cmdL = payload[0];
    int cmdH = payload[1];
    String cmdHex = (cmdH << 8 | cmdL).toRadixString(16).padLeft(4, '0').toUpperCase();
    List<int> realPayload = payload.length > 2 ? payload.sublist(2) : [];

    print('Comando: $cmdHex');
    print('Payload: ${realPayload.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');

    if (cmdHex == '9024') {
      // Comando fictício ou novo — decodificação personalizada aqui:
      return {
        'command': cmdHex,
        'payload': realPayload,
      };
    }

    return {'command': cmdHex, 'payload': realPayload};
  }

  return null;
}
