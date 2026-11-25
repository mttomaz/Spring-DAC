# Registros de decisão arquitetural (ADR)

| ADR | Decisão | Status |
| --- | --- | --- |
| [0001](0001-separacao-bancos.md) | Separar dados relacionais (PostgreSQL) e séries temporais (InfluxDB) | Aceito |
| [0002](0002-mqtt-ingestao-assincrona.md) | Adotar MQTT com TLS e QoS 1 como canal assíncrono de ingestão | Aceito |
| [0003](0003-api-de-consulta.md) | Introduzir uma API de Consulta entre o Dashboard e os bancos | Proposto |

Status "Aceito" vale para o modelo de arquitetura e não comprova implementação, integração ou desempenho. Uma ADR nova entra como "Proposto" e passa a "Aceito" quando o Pull Request é aprovado.
