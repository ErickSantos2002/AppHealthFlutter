# Projeto Bluetooth BLE App

Este projeto é um aplicativo **Flutter** desenvolvido para comunicação com dispositivos **Bluetooth BLE**. Ele permite **escaneamento de dispositivos, conexão, envio de comandos e monitoramento de respostas**, utilizando um protocolo de comunicação pré-definido.

---

## 📌 Índice

- [Pré-requisitos](#pré-requisitos)
- [Instalação](#instalação)
- [Arquitetura do Projeto](#arquitetura-do-projeto)
- [Principais Funcionalidades](#principais-funcionalidades)
- [Protocolo Bluetooth](#protocolo-bluetooth)
- [Como Contribuir](#como-contribuir)
- [Licença](#licença)

---

## ✅ Pré-requisitos

Certifique-se de ter as seguintes ferramentas instaladas antes de iniciar o projeto:

- **Flutter**: Versão 3.0 ou superior.
- **Dart**: Compatível com a versão do Flutter instalado.
- **Dispositivo com Bluetooth BLE**: Para testes e validação.

---

## 🚀 Instalação

### 1️⃣ Clone o repositório:
```bash
git clone https://github.com/JeromeReal/AppHealthSafety.git
cd AppHealthSafety
```

### 2️⃣ Instale as dependências:
```bash
flutter pub get
```

### 3️⃣ Inicie o projeto:
```bash
flutter run
```

### 4️⃣ Para um dispositivo específico (Android):
```bash
flutter devices
flutter run -d <device_id>
```

---

## 🏠 Barra de Navegação

O aplicativo possui um **menu inferior** com as seguintes telas:

### 1️⃣ **Perfil**
- Exibe as informações do usuário, incluindo **E-mail, Nome, Endereço e Telefone**.
- Possui um botão **"Salvar"** para atualizar as informações.

### 2️⃣ **Histórico**
- Contém um **gráfico de barras** exibindo a quantidade de registros por dia no mês.
- O usuário pode selecionar o **mês** no topo da tela.
- Abaixo do gráfico, há uma **lista de registros**.
- Uma segunda aba **"Reprovados"** exibe apenas os testes reprovados.

### 3️⃣ **Informações do Dispositivo**
- Exibe informações coletadas do dispositivo via **Bluetooth BLE**, incluindo:
  - **Bluetooth**
  - **Data de calibração**
  - **Próxima calibração**
  - **Testes restantes**
  - **Unidade atual**
  - **Uso total**
  - **Contagem de uso após calibração**
  - **Número de rejeições de álcool**
  - **Versão do firmware**

### 4️⃣ **Configurações**
- Possui diversas **configurações do aparelho** que podem ser ativadas/desativadas.
- Permite **exportar registros** e **verificar a versão do aplicativo**.

---

## 📂 Arquitetura do Projeto

A estrutura do projeto é organizada da seguinte forma:

```plaintext
/lib
 ├── main.dart                    # Arquivo principal
 ├── theme.dart                    # Tema global do app
 ├── services/                      # Serviços reutilizáveis
 │    ├── bluetooth_service.dart    # Gerenciamento do BLE
 │    ├── bluetooth_manager.dart    # Controle da conexão e comandos BLE
 │    ├── connection_state.dart     # Monitoramento do estado da conexão
 │    ├── bluetooth_scan_service.dart # Serviço de escaneamento BLE
 ├── screens/                       # Telas do app
 │    ├── main_screen.dart          # Menu de navegação
 │    ├── home_screen.dart          # Tela principal
 │    ├── perfil_screen.dart        # Tela de perfil
 │    ├── historico_screen.dart     # Histórico de testes
 │    ├── informacoes_dispositivo_screen.dart # Info do dispositivo
 │    ├── configuracoes_screen.dart # Configurações do app
 ├── models/                        # Modelos do banco de dados
 │    ├── test_model.dart           # Modelo de dados dos testes
 ├── widgets/                       # Componentes reutilizáveis
 ├── docs/
 │    ├── BLE_Protocol.md           # Detalhes sobre o protocolo BLE
 │    ├── Architecture.md           # Estrutura do projeto
```

---

## ⚡ Principais Funcionalidades

✅ **Escanear dispositivos BLE** → Identifica dispositivos Bluetooth próximos.  
✅ **Conectar ao dispositivo BLE** → Estabelece conexão segura com um dispositivo específico.  
✅ **Enviar comandos BLE** → Permite o envio de comandos como `A20` para iniciar um teste.  
✅ **Monitoramento de dados** → Recebe notificações e respostas de estados do dispositivo.  
✅ **Histórico de Testes** → Exibe os testes salvos, gráficos e separação de aprovados/reprovados.  

---

## 🔗 Protocolo Bluetooth

A comunicação segue a estrutura abaixo:

### **📌 Estrutura do Pacote**
| Campo    | Tamanho  | Descrição                          |
|----------|---------|----------------------------------|
| STX      | 1 byte  | Sempre 0x02.                     |
| Command  | 3 bytes | Código do comando (e.g., `A20`). |
| Data     | 13 bytes | Dados relacionados ao comando.   |
| BAT      | 1 byte  | Nível da bateria.                |
| BCC      | 1 byte  | Checksum para validação.         |
| ETX      | 1 byte  | Sempre 0x03.                     |

### **📌 Exemplo de Pacote**
```plaintext
STX | Command | Data             | BAT | BCC | ETX
02H   A20       TEST,START####     04    F6    03H
```

### **📌 Comandos Suportados**
| Comando  | Descrição                        | Dados Enviados            | Exemplo de Dados |
|----------|---------------------------------|---------------------------|------------------|
| A01      | Versão do Firmware              | `INFORMATION`              | `0.02,AL8800BT` |
| A03      | Contagem de Uso                 | `0`, `1` ou `2`            | -                |
| A04      | Informação de Calibração        | `0`, `1` ou `2`            | -                |
| A05      | Mudar unidade de medida         | `0` a `5`                  | -                |
| A06      | Verificar Alarme Calibração     | `CAL,CHECK`                | -                |
| A19      | Mudança de volume               | `0` a `4`                  | -                |
| A20      | Iniciar Teste                   | `TEST,START`               | -                |
| A22      | Voltar para espera              | `SOFT,RESET`               | -                |

### **📌 Respostas dos Comandos**
| Comando | Descrição            | Exemplo de Dados       |
|---------|----------------------|------------------------|
| T12     | Contagem Regressiva  | `299##########`       |
| T10     | Estado de Análise    | `ANALYZING####`       |
| T11     | Resultados da Análise | `1,3,0.000,0##`       |

---

## 🤝 Como Contribuir

1. Faça um **fork** do projeto.
2. Crie uma **branch** para suas alterações:
   ```bash
   git checkout -b minha-nova-feature
   ```
3. Faça o **commit** das alterações:
   ```bash
   git commit -m "Adicionei nova funcionalidade"
   ```
4. Envie as alterações para o repositório remoto:
   ```bash
   git push origin minha-nova-feature
   ```
5. **Crie um Pull Request** no GitHub.

---

## 📜 Licença

Este projeto está licenciado sob a **Licença MIT**.

📩 **Contato**  
Caso tenha dúvidas ou sugestões, entre em contato por meio do repositório.
```
