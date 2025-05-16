
# Health App

Aplicativo **Flutter** para comunicação com dispositivos **Bluetooth BLE**, desenvolvido pela **Health Safety**. Permite **escaneamento, conexão, envio de comandos e monitoramento de respostas** de dispositivos de alcoolemia, seguindo um protocolo de comunicação próprio.

---

## 📌 Índice

- [Sobre o Projeto](#sobre-o-projeto)
- [Pré-requisitos](#pré-requisitos)
- [Instalação](#instalação)
- [Arquitetura do Projeto](#arquitetura-do-projeto)
- [Funcionalidades](#funcionalidades)
- [Protocolo de Comunicação](#protocolo-de-comunicação)
- [Contribuindo](#contribuindo)
- [Contato](#contato)
- [Licença](#licença)

---

## 📝 Sobre o Projeto

O **Health App** foi desenvolvido para facilitar a **gestão e operação de dispositivos de alcoolemia via Bluetooth BLE**, oferecendo uma interface intuitiva e um fluxo de trabalho otimizado para monitoramento de testes, status de calibração e exportação de dados.

👉 Focado em empresas que priorizam a **segurança no ambiente de trabalho**, o app conecta diretamente com os aparelhos, garantindo praticidade e eficiência no controle do uso.

---

## ✅ Pré-requisitos

- **Flutter**: Versão 3.0 ou superior.
- **Dart**: Compatível com a versão do Flutter.
- **Dispositivo com Bluetooth BLE**: Para testes reais.
- **Android SDK configurado**: (recomendado Android 9+).

---

## 🚀 Instalação

```bash
git clone https://github.com/JeromeReal/HealthApp.git
cd HealthApp
flutter pub get
flutter run
```

Para dispositivos Android específicos:

```bash
flutter devices
flutter run -d <device_id>
```

---

## 🏗️ Arquitetura do Projeto

Organização baseada em **boas práticas Flutter**:

```
/lib
 ├── main.dart                    # Entrada principal do app
 ├── theme.dart                   # Definição do tema global
 ├── services/                    # Lógica e comunicação BLE
 ├── screens/                     # Telas do aplicativo (UI)
 ├── models/                      # Modelos de dados
 ├── providers/                   # Gerenciamento de estado (Riverpod)
 ├── widgets/                     # Componentes reutilizáveis
 └── docs/                        # Documentação técnica
```

---

## ⚡ Funcionalidades

- 🔍 **Escanear dispositivos BLE**.
- 🔗 **Conectar e desconectar** do dispositivo.
- 📨 **Enviar comandos** (ex: iniciar teste de alcoolemia).
- 📊 **Visualizar histórico** com gráficos e filtros.
- 📱 **Monitorar status do dispositivo** (calibração, usos restantes, firmware).
- 🗃️ **Exportar registros de testes em CSV**.
- ⚙️ **Configurações avançadas** do app e do dispositivo.
- 📲 **Atalhos para suporte via WhatsApp e e-mail**.

---

## 📡 Protocolo de Comunicação

### Estrutura do Pacote BLE
| Campo    | Tamanho  | Descrição |
|----------|----------|-----------|
| STX      | 1 byte   | Sempre 0x02 |
| Command  | 3 bytes  | Código do comando (ex: A20) |
| Data     | 13 bytes | Dados do comando |
| BAT      | 1 byte   | Nível da bateria |
| BCC      | 1 byte   | Checksum |
| ETX      | 1 byte   | Sempre 0x03 |

### Comandos Suportados
| Comando  | Descrição |
|----------|-----------|
| A01      | Versão do Firmware |
| A03      | Contagem de Uso |
| A04      | Info de Calibração |
| A05      | Unidade de Medida |
| A06      | Verificar Alarme |
| A19      | Ajustar Volume |
| A20      | Iniciar Teste |
| A22      | Reset para Espera |

---

## 🤝 Contribuindo

1. Fork este repositório.
2. Crie sua branch: `git checkout -b minha-feature`.
3. Commit suas alterações: `git commit -m 'Descrição da alteração'`.
4. Push: `git push origin minha-feature`.
5. Abra um Pull Request.

---

## 📩 Contato

Dúvidas ou sugestões?

📧 **suporte@healthsafety.com.br**  
🌐 [www.healthsafety.com.br](https://www.healthsafety.com.br)

---

## 📜 Licença

Distribuído sob a licença **MIT**. Veja [LICENSE](LICENSE) para mais informações.

---

### 🟢 Status Atual:  
✅ Primeira versão publicada nas lojas.
